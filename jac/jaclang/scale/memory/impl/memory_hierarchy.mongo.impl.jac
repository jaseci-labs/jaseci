import os;
import from jaclang.scale.runtime.context.tracing { start_memory_span, end_memory_span }
import from jaclang.runtimelib.exceptions { WriteConflict }

impl MongoBackend.postinit -> None {
    if self.mongo_url is None {
        self.mongo_url = _get_db_config().get('mongodb_uri');
    }
    if self.mongo_url {
        if 'mongo_client' not in _process_cache {
            try {
                _process_cache['mongo_client'] = MongoClient(self.mongo_url);
            } except Exception as e {
                logger.warning(f"MongoDB connection failed: {e}");
            }
        }
        self.client = _process_cache.get('mongo_client');
        if self.client {
            self.db = self.client[self.db_name];
            self.collection = self.db[self.collection_name];
        }
    }
    if self.client is not None {
        try {
            self._load_db_aliases();
        } except Exception as e {
            logger.debug(f"MongoBackend: alias preload skipped: {e}");
        }
        try {
            self.ensure_indexes();
        } except Exception as e {
            logger.debug(f"MongoBackend: index creation skipped: {e}");
        }

        try {
            self._auto_retry_quarantine();
        } except Exception as e {
            logger.debug(f"MongoBackend: quarantine auto-retry skipped: {e}");
        }
    }
}


impl MongoBackend.ensure_indexes -> None {
    if self.collection is None {
        return;
    }
    import from pymongo { ASCENDING, DESCENDING }
    self.collection.create_index(
        [('arch_type', ASCENDING), ('type', ASCENDING)],
        name='arch_type_1_type_1',
        background=True
    );
    self.collection.create_index(
        [('updated_at', DESCENDING)], name='updated_at_-1', background=True
    );
}

def _mongo_q_collection(backend: MongoBackend) -> any {
    return backend.db[backend.collection_name + '_quarantine'];
}

def _mongo_a_collection(backend: MongoBackend) -> any {
    return backend.db[backend.collection_name + '_aliases'];
}

def _anchor_has_structural_change(anchor: Anchor) -> bool {
    return anchor.hash == 0;
}

def _anchor_to_doc(anchor: Anchor) -> dict {
    data = Serializer.serialize(anchor, include_type=True);
    anchor_type = type(anchor).__name__;
    arch_module: (str | None) = None;
    arch_type: (str | None) = None;
    fingerprint: (str | None) = None;
    if anchor.is_populated() and anchor.archetype is not None {
        arch = anchor.archetype;
        arch_module = type(arch).__module__;
        arch_type = type(arch).__name__;
        fp = type(arch)?.__jac_fingerprint__;
        fingerprint = fp if isinstance(fp, str) and fp else None;
    }
    return {
        'type': anchor_type,
        'arch_module': arch_module,
        'arch_type': arch_type,
        'fingerprint': fingerprint,
        'data': data,
        'format_version': 1,
        'updated_at': datetime.now(timezone.utc).isoformat()
    };
}

def _mongo_persist_repairs(
    backend: MongoBackend, id_str: str, anchor: Anchor, stored_fp: (str | None)
) -> None {
    arch = anchor.archetype if anchor.is_populated() else None;
    if arch is None {
        return;
    }
    steps = arch.__dict__.get('__jac_schema_repairs__');
    if not steps {
        return;
    }
    try {
        doc = _anchor_to_doc(anchor);
        result = backend.collection.update_one(
            {'_id': id_str, 'fingerprint': stored_fp}, {'$set': doc}
        );
        if result.matched_count {
            logger.info(
                f"MongoBackend: persisted read-repair of {id_str} "
                f"({doc.get('arch_module')}.{doc.get('arch_type')}): {steps}"
            );
            if backend._l2_ref {
                backend._l2_ref.delete(to_uuid(anchor.id));
            }
        } else {
            logger.info(
                f"MongoBackend: read-repair write-back of {id_str} skipped "
                "(concurrent write since load); will repair on next read."
            );
        }

        arch.__dict__.pop('__jac_schema_repairs__', None);
    } except Exception as e {
        logger.warning(f"MongoBackend: read-repair write-back of {id_str} failed: {e}");
    }
}


def _mongo_quarantine(
    backend: MongoBackend,
    id_str: str,
    anchor_type: (str | None),
    arch_module: (str | None),
    arch_type: (str | None),
    fingerprint: (str | None),
    data: any,
    error: str,
    from_format_version: (int | None) = None,
    l2: (any | None) = None,
    reason_code: str = 'DESER_ERROR'
) {
    try {
        q_col = _mongo_q_collection(backend);
        now_ts = datetime.now(timezone.utc).isoformat();
        q_col.update_one(
            {'_id': id_str},
            {
                '$set': {
                    'type': anchor_type,
                    'arch_module': arch_module,
                    'arch_type': arch_type,
                    'fingerprint': fingerprint,
                    'data': data,
                    'error': error,
                    'reason_code': reason_code,
                    'quarantined_at': now_ts,
                    'from_format_version': from_format_version
                }
            },
            upsert=True
        );
        backend.collection.delete_one({'_id': id_str});
        if l2 {
            l2.delete(to_uuid(id_str));
            l2.publish_invalidation(str(to_uuid(id_str)), None);
        }

        if anchor_type == 'NodeAnchor' {
            orphaned_edges = list(
                backend.collection.find(
                    {
                        'type': 'EdgeAnchor',
                        '$or': [{'data.source': id_str}, {'data.target': id_str}]
                    }
                )
            );
            if orphaned_edges {
                orphan_edge_ids = [e['_id'] for e in orphaned_edges];

                affected_node_ids = [];
                if l2 {
                    affected_nodes = backend.collection.find(
                        {'type': 'NodeAnchor', 'data.edges': {'$in': orphan_edge_ids}},
                        {'_id': 1}
                    );
                    affected_node_ids = [doc['_id'] for doc in affected_nodes];
                }
                cascade_error = f"cascade quarantine: connected node {id_str} was quarantined";
                cascade_ops = [
                    UpdateOne(
                        {'_id': edge_doc['_id']},
                        {
                            '$set': {
                                'type': edge_doc.get('type'),
                                'arch_module': edge_doc.get('arch_module'),
                                'arch_type': edge_doc.get('arch_type'),
                                'fingerprint': edge_doc.get('fingerprint'),
                                'data': edge_doc.get('data'),
                                'error': cascade_error,
                                'reason_code': 'CASCADE',
                                'quarantined_at': now_ts,
                                'from_format_version': edge_doc.get('format_version')
                            }
                        },
                        upsert=True
                    ) for edge_doc in orphaned_edges
                ];
                q_col.bulk_write(cascade_ops, ordered=False);
                backend.collection.delete_many({'_id': {'$in': orphan_edge_ids}});
                if l2 {
                    for eid in orphan_edge_ids {
                        l2.delete(to_uuid(eid));
                        l2.publish_invalidation(str(to_uuid(eid)), None);
                    }
                }
                backend.collection.update_many(
                    {'type': 'NodeAnchor', 'data.edges': {'$in': orphan_edge_ids}},
                    {'$pullAll': {'data.edges': orphan_edge_ids}}
                );
                if l2 {
                    for nid in affected_node_ids {
                        l2.delete(to_uuid(nid));
                        l2.publish_invalidation(str(to_uuid(nid)), None);
                    }
                }
                logger.info(
                    f"MongoBackend: cascade-quarantined {len(orphan_edge_ids)} edge(s) "
                    f"connected to quarantined node {id_str}."
                );
            }
        }
    } except Exception as e {
        logger.error(f"MongoBackend: failed to quarantine {id_str}: {e}");
    }
}

impl MongoBackend.set_cache_ref(cache: (any | None)) -> None {
    self._l2_ref = cache;
}

impl MongoBackend.set_l1_id(l1_id: str) -> None {
    self._l1_id = l1_id;
}

impl MongoBackend.is_available -> bool {
    if _process_cache.get('mongo_available') is True {
        return True;
    }
    if not self.mongo_url {
        self.mongo_url = _get_db_config().get('mongodb_uri');
    }
    if not self.mongo_url or self.client is None {
        return False;
    }
    try {
        self.client.admin.command('ping', maxTimeMS=100);
        _process_cache['mongo_available'] = True;
        return True;
    } except ConnectionFailure {
        _process_cache['mongo_available'] = False;
        return False;
    } except Exception as e {
        logger.debug(f"MongoDB availability check failed: {e}");
        _process_cache['mongo_available'] = False;
        return False;
    }
}

impl MongoBackend.get(id: UUID) -> (Anchor | None) {
    if self.client is None {
        return None;
    }
    self.fetch_count += 1;
    _id = to_uuid(id);
    span = start_memory_span(
        "memory.get mongodb",
        {"db.system": "mongodb", "mem.tier": "L3", "mem.op": "get"}
    );
    try {
        db_obj = self.collection.find_one({'_id': str(_id)});
    } except Exception as e {
        logger.debug(f"MongoDB get failed: {e}");
        return None;
    } finally {
        end_memory_span(span);
    }
    if not db_obj {
        return None;
    }
    anchor_type = db_obj.get('type');
    arch_module = db_obj.get('arch_module');
    arch_type = db_obj.get('arch_type');
    fingerprint = db_obj.get('fingerprint');
    data = db_obj.get('data');
    fmt_version = db_obj.get('format_version');

    if arch_module and arch_type and fingerprint {
        cls = Serializer._get_class(arch_module, arch_type);
        current_fp = cls?.__jac_fingerprint__ if cls else None;
        if current_fp and current_fp != fingerprint {
            logger.info(
                f"MongoBackend: schema drift on {arch_module}.{arch_type} "
                f"(stored={fingerprint}, current={current_fp}, id={id}); "
                "attempting best-effort load."
            );
        }
    }
    try {
        anchor = Serializer.deserialize(data) if data is not None else None;
    } except Exception as e {
        logger.warning(
            f"MongoBackend: failed to deserialize anchor {id} "
            f"({arch_module}.{arch_type}): {type(e).__name__}: {e}. "
            "Moving to quarantine."
        );
        _mongo_quarantine(
            self,
            str(_id),
            anchor_type,
            arch_module,
            arch_type,
            fingerprint,
            data,
            f"deserialize error: {type(e).__name__}: {e}",
            from_format_version=fmt_version,
            l2=self._l2_ref,
            reason_code='DESER_ERROR'
        );
        return None;
    }
    if anchor is None {
        cls_resolved = (
            Serializer._get_class(arch_module, arch_type)
                if (arch_module and arch_type)
                else None
        );
        if cls_resolved is None {
            if os.environ.get("JAC_SV_SIBLING") == "1" {
                logger.debug(
                    f"MongoBackend: class {arch_module}.{arch_type} not "
                    f"loaded in this sibling service; skipping anchor {id} "
                    "(owned by a peer service)."
                );
                return None;
            }
            reason = f"class {arch_module}.{arch_type} unresolvable";
            code = 'CLASS_MISSING';
            logger.warning(
                f"MongoBackend: class {arch_module}.{arch_type} unresolvable "
                f"for anchor {id}. Moving to quarantine."
            );
        } else {
            reason = f"archetype field deserialization failed: {arch_module}.{arch_type}";
            code = 'FIELD_RECONSTRUCT';
            logger.warning(
                f"MongoBackend: archetype field deserialization failed for "
                f"{arch_module}.{arch_type} (anchor {id}). Moving to quarantine."
            );
        }
        _mongo_quarantine(
            self,
            str(_id),
            anchor_type,
            arch_module,
            arch_type,
            fingerprint,
            data,
            reason,
            from_format_version=fmt_version,
            l2=self._l2_ref,
            reason_code=code
        );
        return None;
    }
    _mongo_persist_repairs(self, str(_id), cast(Anchor, anchor), fingerprint);
    snapshot_field_hashes(cast(Anchor, anchor));
    return cast(Anchor, anchor);
}

impl MongoBackend.put(anchor: Anchor) -> None { }

impl MongoBackend._write_to_db(anchor: Anchor) -> None {
    if self.client is None or not anchor.persistent {
        return;
    }
    self.put_count += 1;
    _id = to_uuid(anchor.id);
    arch = anchor.archetype if anchor.is_populated() else None;
    try {
        doc = _anchor_to_doc(anchor);
        self.collection.update_one({'_id': str(_id)}, {'$set': doc}, upsert=True);
        anchor.hash = Serializer._compute_hash(anchor);
        snapshot_field_hashes(anchor);
    } except Exception as e {
        logger.error(f"MongoDB _write_to_db failed: {e}");
        raise;
    }
}

impl MongoBackend.put_partial(anchor: Anchor, field_names: set[str]) -> None {
    if self.client is None or not anchor.persistent or not field_names {
        return;
    }
    _id = to_uuid(anchor.id);
    try {
        partial_data = Serializer.serialize_fields(anchor, field_names);
        if not partial_data {
            return;
        }
        update: dict[str, object] = {
            f"data.archetype.{k}": v for (k, v) in partial_data.items()
        };
        update['updated_at'] = datetime.now(timezone.utc).isoformat();
        self.collection.update_one({'_id': str(_id)}, {'$set': update});
        anchor.hash = Serializer._compute_hash(anchor);
        snapshot_field_hashes(anchor);
    } except Exception as e {
        logger.error(f"MongoDB put_partial failed: {e}");
        raise;
    }
}

impl MongoBackend.delete(id: UUID) -> None { }

impl MongoBackend.close -> None {
    self.client = None;
    self._l2_ref = None;
}

impl MongoBackend.`has(id: UUID) -> bool {
    if self.client is None {
        return False;
    }
    _id = to_uuid(id);
    try {
        return self.collection.count_documents({'_id': str(_id)}, limit=1) > 0;
    } except Exception {
        return False;
    }
}

impl MongoBackend.query(
    filter: (Callable[[Anchor], bool] | None) = None
) -> Generator[Anchor, None, None] {
    if self.client is None {
        return;
    }
    try {
        for doc in self.collection.find() {
            if (anchor := self._load_anchor(doc)) {
                if filter is None or filter(anchor) {
                    yield anchor;
                }
            }
        }
    } except Exception as e {
        logger.debug(f"MongoDB query failed: {e}");
    }
}

impl MongoBackend.get_roots -> Generator[Root, None, None] {
    if self.client is None {
        return;
    }
    try {
        for doc in self.collection.find({'arch_type': 'Root', 'type': 'NodeAnchor'}) {
            if (anchor := self._load_anchor(doc)) {
                if isinstance(anchor.archetype, Root) {
                    yield cast(Root, anchor.archetype);
                }
            }
        }
    } except Exception as e {
        logger.debug(f"MongoDB get_roots failed: {e}");
    }
}


def _mongo_types_col(backend: MongoBackend) -> any {
    return backend.collection.database['graph_types'];
}


def _mongo_record_ancestry(backend: MongoBackend, cls: type) {
    import from jaclang.jac0core.archetype {
        Archetype,
        EdgeArchetype,
        NodeArchetype,
        WalkerArchetype
    }
    stops = (NodeArchetype, EdgeArchetype, WalkerArchetype, Archetype, object);
    try {
        col = _mongo_types_col(backend);
        for c in type(cls).__mro__ if not isinstance(cls, type) else cls.__mro__ {
            if c in stops {
                break;
            }
            col.update_one(
                {'_id': f"{cls.__name__}::{c.__name__}"},
                {'$set': {'type_name': cls.__name__, 'ancestor': c.__name__}},
                upsert=True
            );
        }
    } except Exception as e {
        logger.debug(f"MongoDB ancestry record failed: {e}");
    }
}


def _mongo_type_names(backend: MongoBackend, cls: type) -> list[str] {
    names: list[str] = [cls.__name__];
    try {
        col = _mongo_types_col(backend);
        for doc in col.find({'ancestor': cls.__name__}, {'type_name': 1}) {
            tn = doc.get('type_name');
            if tn and tn not in names {
                names.append(tn);
            }
        }
    } except Exception as e {
        logger.debug(f"MongoDB ancestry lookup failed: {e}");
    }
    return names;
}


def _mongo_pred_filter(preds: list[QPred]) -> dict {
    filt: dict = {};
    for p in preds {
        v = p.value;
        if isinstance(v, UUID) {
            v = str(v);
        }
        key = f"data.archetype.{p.field}";
        if p.op == '==' {
            filt[key] = {'$eq': v};
        } elif p.op == '!=' {
            filt[key] = {'$ne': v};
        } elif p.op == 'in' {
            vals = [str(x) if isinstance(x, UUID) else x for x in p.value];
            filt[key] = {'$in': vals};
        } elif p.op == '<' {
            filt[key] = {'$lt': v};
        } elif p.op == '<=' {
            filt[key] = {'$lte': v};
        } elif p.op == '>' {
            filt[key] = {'$gt': v};
        } else {
            filt[key] = {'$gte': v};
        }
    }
    return filt;
}


impl MongoBackend.hop_rows(
    src_ids: list[UUID], hop: QHop, ordered: bool = False
) -> (list[tuple[UUID, UUID]] | None) {
    if self.client is None or not src_ids {
        return [];
    }
    keys = [str(i) for i in src_ids];
    arms: list;
    if hop.dir == 1 {
        arms = [
            ('data.target', 'data.source', False),
            ('data.source', 'data.target', True)
        ];
    } elif hop.dir == 3 {
        arms = [
            ('data.source', 'data.target', False),
            ('data.target', 'data.source', False)
        ];
    } else {
        arms = [
            ('data.source', 'data.target', False),
            ('data.target', 'data.source', True)
        ];
    }
    base: dict = {'type': 'EdgeAnchor'};
    if hop.`edge is not None {
        base['arch_type'] = {'$in': _mongo_type_names(self, hop.`edge)};
    }
    rows: list = [];
    try {
        for (mkey, nkey, undir_only) in arms {
            filt = dict(base);
            filt[mkey] = {'$in': keys};
            if undir_only {
                filt['data.is_undirected'] = True;
            }
            proj = {'_id': 1, 'data.source': 1, 'data.target': 1};
            for doc in self.collection.find(filt, proj).sort('_id', 1) {
                data = doc.get('data') or {};
                nbr = data.get(nkey.split('.')[-1]);
                if nbr {
                    rows.append((str(doc['_id']), str(nbr)));
                }
            }
        }
        nd = hop.nd;
        node_types = (
            nd if isinstance(nd, tuple) else ((nd, ) if nd is not None else ())
        );
        if node_types {
            nbr_ids = list({r[1] for r in rows});
            keep: set = set(nbr_ids);
            for nt in node_types {
                nfilt = {
                    '_id': {
                        '$in': [
                            k
                            for k in nbr_ids
                            if k in keep
                        ]
                    },
                    'arch_type': {'$in': _mongo_type_names(self, nt)}
                };
                got = {str(d['_id']) for d in self.collection.find(nfilt, {'_id': 1})};
                keep = keep & got;
            }
            rows = [
                r
                for r in rows
                if r[1] in keep
            ];
        }
    } except Exception as e {
        logger.debug(f"MongoDB hop_rows failed: {e}");
        return [];
    }
    return [(UUID(a), UUID(b)) for (a, b) in rows];
}


impl MongoBackend.edge_endpoints(
    ids: list[UUID]
) -> (dict[UUID, tuple[UUID, UUID]] | None) {
    if not ids or self.client is None {
        return {};
    }
    out: dict[UUID, tuple[UUID, UUID]] = {};
    try {
        filt = {'_id': {'$in': [str(i) for i in ids]}, 'type': 'EdgeAnchor'};
        proj = {'_id': 1, 'data.source': 1, 'data.target': 1};
        for doc in self.collection.find(filt, proj) {
            data = doc.get('data') or {};
            s_id = data.get('source');
            t_id = data.get('target');
            if s_id and t_id {
                out[UUID(str(doc['_id']))] = (UUID(str(s_id)), UUID(str(t_id)));
            }
        }
    } except Exception as e {
        logger.debug(f"MongoDB edge_endpoints failed: {e}");
    }
    return out;
}


def _mongo_scalar_cols(arch: any) -> dict {
    out: dict = {};
    if isinstance(arch, dict) {
        for (k, v) in arch.items() {
            if isinstance(k, str) and not k.startswith('$') and not k.startswith('_') {
                if v is None or isinstance(v, (str, int, float, bool)) {
                    out[k] = v;
                }
            }
        }
    }
    return out;
}


def _mongo_ancestry_map(backend: MongoBackend, names: set[str]) -> dict[str, tuple] {
    out: dict[str, tuple] = {};
    if names {
        try {
            col = _mongo_types_col(backend);
            for doc in col.find(
                {'type_name': {'$in': list(names)}}, {'type_name': 1, 'ancestor': 1}
            ) {
                tn = doc.get('type_name');
                if tn {
                    out[tn] = out.get(tn, ()) + (doc.get('ancestor'), );
                }
            }
        } except Exception as e {
            logger.debug(f"MongoDB ancestry map failed: {e}");
        }
    }
    for n in names {
        if n not in out {
            out[n] = (n, );
        }
    }
    return out;
}


impl MongoBackend.node_pages(ids: list[UUID]) -> (dict[UUID, dict] | None) {
    if not ids or self.client is None {
        return {};
    }
    out: dict[UUID, dict] = {};
    try {
        keys = [str(i) for i in ids];
        key_set = set(keys);
        proj_n = {'_id': 1, 'arch_type': 1, 'data.archetype': 1};
        node_facts: dict[str, tuple] = {};
        for doc in self.collection.find({'_id': {'$in': keys}}, proj_n) {
            data = doc.get('data') or {};
            node_facts[str(doc['_id'])] = (
                doc.get('arch_type') or '',
                _mongo_scalar_cols(data.get('archetype'))
            );
        }
        proj_e = {
            '_id': 1,
            'arch_type': 1,
            'data.source': 1,
            'data.target': 1,
            'data.is_undirected': 1,
            'data.archetype': 1
        };
        adj_rows: list = [];
        efilt = {
            'type': 'EdgeAnchor',
            '$or': [{'data.source': {'$in': keys}}, {'data.target': {'$in': keys}}]
        };
        for doc in self.collection.find(efilt, proj_e).sort('_id', 1) {
            data = doc.get('data') or {};
            src = data.get('source');
            tgt = data.get('target');
            if src and tgt {
                adj_rows.append(
                    (
                        str(doc['_id']),
                        str(src),
                        str(tgt),
                        doc.get('arch_type') or '',
                        bool(data.get('is_undirected')),
                        _mongo_scalar_cols(data.get('archetype'))
                    )
                );
            }
        }
        nbr_ids = list(
            {(r[2] if r[1] in key_set else r[1]) for r in adj_rows} - key_set
        );
        nbr_facts: dict[str, tuple] = {};
        if nbr_ids {
            for doc in self.collection.find({'_id': {'$in': nbr_ids}}, proj_n) {
                data = doc.get('data') or {};
                nbr_facts[str(doc['_id'])] = (
                    doc.get('arch_type') or '',
                    _mongo_scalar_cols(data.get('archetype'))
                );
            }
        }
        tnames: set[str] = set();
        for (tn, _) in node_facts.values() {
            tnames.add(tn);
        }
        for r in adj_rows {
            tnames.add(r[3]);
        }
        for (tn, _) in nbr_facts.values() {
            tnames.add(tn);
        }
        anc = _mongo_ancestry_map(self, tnames);
        for k in keys {
            facts = node_facts.get(k);
            if facts is None {
                continue;
            }
            (tn, cols) = facts;
            out[UUID(k)] = {
                'ancestors': list(anc.get(tn, (tn, ))),
                'cols': cols,
                'adj': [],
                'nbr': {}
            };
        }
        for (eid, src, tgt, etype, undir, e_cols) in adj_rows {
            e_anc = anc.get(etype, (etype, ));
            arms = (
                [(src, tgt, True), (tgt, src, False)]
                    if src != tgt
                    else [(src, tgt, True)]
            );
            for (owner, other, is_out) in arms {
                page = out.get(UUID(owner)) if owner in key_set else None;
                if page is None {
                    continue;
                }
                page['adj'].append(
                    (UUID(eid), e_anc, undir, is_out, UUID(other), e_cols)
                );
                if other not in key_set {
                    o_facts = nbr_facts.get(other);
                    if o_facts is not None {
                        (otn, ocols) = o_facts;
                        page['nbr'][UUID(other)] = (anc.get(otn, (otn, )), ocols);
                    }
                }
            }
        }
    } except Exception as e {
        logger.debug(f"MongoDB node_pages failed: {e}");
        return {};
    }
    return out;
}


impl MongoBackend.existing_ids(ids: list[UUID]) -> (set[UUID] | None) {
    if not ids or self.client is None {
        return set();
    }
    out: set[UUID] = set();
    try {
        filt = {'_id': {'$in': [str(i) for i in ids]}};
        for doc in self.collection.find(filt, {'_id': 1}) {
            out.add(UUID(str(doc['_id'])));
        }
    } except Exception as e {
        logger.debug(f"MongoDB existing_ids failed: {e}");
    }
    return out;
}


impl MongoBackend.filter_ids(
    ids: list[UUID], preds: list[QPred]
) -> (set[UUID] | None) {
    if not ids or not preds {
        return set(ids);
    }
    if self.client is None {
        return set();
    }
    filt = _mongo_pred_filter(preds);
    filt['_id'] = {'$in': [str(i) for i in ids]};
    out: set[UUID] = set();
    try {
        for doc in self.collection.find(filt, {'_id': 1}) {
            out.add(UUID(str(doc['_id'])));
        }
    } except Exception as e {
        logger.debug(f"MongoDB filter_ids failed: {e}");
    }
    return out;
}

impl MongoBackend.commit(anchor: (Anchor | None) = None) -> None { }

impl MongoBackend.apply(changeset: ChangeSet) -> ApplyReport {
    apply_report = ApplyReport();
    if changeset.is_empty() or self.client is None {
        return apply_report;
    }
    span = start_memory_span(
        "memory.apply mongodb",
        {"db.system": "mongodb", "mem.tier": "L3", "mem.op": "apply"}
    );
    try {
        poisoned: set[UUID] = set();

        read_gated: dict[str, int] = {};
        for stage in changeset.staged() {
            for intent in stage {
                if intent.cas_version is not None {
                    read_gated[str(to_uuid(intent.anchor.id))] = intent.cas_version;
                }
            }
        }
        precheck: list = [];
        if read_gated {
            stored_versions: dict[str, int] = {};
            for vdoc in self.collection.find(
                {'_id': {'$in': list(read_gated.keys())}}, {'data.version': 1}
            ) {
                stored_versions[str(vdoc.get('_id'))] = int(
                    vdoc.get('data', {}).get('version', 0)
                );
            }

            for (gid, expected) in read_gated.items() {
                if gid in stored_versions and stored_versions[gid] != expected {
                    precheck.append(
                        WriteConflict(
                            anchor_id=to_uuid(gid),
                            expected_version=expected,
                            actual_version=stored_versions[gid]
                        )
                    );
                }
            }
        }
        if precheck {
            for wc in precheck {
                apply_report.failed[wc.anchor_id] = wc.message();
                apply_report.conflicts.append(wc);
            }
            if span {
                span.set_attribute("mem.count", 0);
            }
            return apply_report;
        }
        for stage in changeset.staged() {
            for intent in stage {
                if (deps := intent.depends_on & poisoned) {
                    dep = next(iter(deps));
                    apply_report.skipped[intent.anchor.id] = f"dependency {dep} failed";
                    poisoned.add(intent.anchor.id);
                    logger.error(
                        f"MongoDB apply: skipping {intent.op.name} on "
                        f"{intent.anchor.id}: dependency {dep} failed"
                    );
                    continue;
                }
                try {
                    self._apply_one(intent);
                    apply_report.applied.append(intent.anchor.id);
                } except WriteConflict as wc {
                    poisoned.add(intent.anchor.id);
                    apply_report.failed[intent.anchor.id] = wc.message();
                    apply_report.conflicts.append(wc);
                    logger.debug(
                        f"MongoDB apply: write conflict on {intent.anchor.id}: "
                        f"{wc.message()}"
                    );
                } except Exception as e {
                    poisoned.add(intent.anchor.id);
                    apply_report.failed[intent.anchor.id] = str(e);
                    logger.error(
                        f"MongoDB apply: {intent.op.name} failed for "
                        f"{intent.anchor.id}: {type(e).__name__}: {e}"
                    );
                }
            }
        }
        if span {
            span.set_attribute("mem.count", len(apply_report.applied));
        }
        return apply_report;
    } finally {
        end_memory_span(span);
    }
}

impl MongoBackend._apply_one(intent: WriteIntent) -> None {
    anchor = intent.anchor;
    if intent.is_delete() {
        self.collection.delete_one({'_id': str(to_uuid(anchor.id))});
        return;
    }
    if intent.op == WriteOp.EDGE_LIST_DELTA {
        self._put_node_atomic(
            cast(NodeAnchor, anchor),
            [str(eid) for eid in intent.edges_added],
            [str(eid) for eid in intent.edges_removed],
            intent.fields,
            intent.cas_version
        );
        return;
    }
    if intent.op == WriteOp.FIELD_UPDATE {
        self.put_partial(anchor, intent.fields);
        return;
    }

    self._write_to_db(anchor);
}

impl MongoBackend._put_node_atomic(
    anchor: NodeAnchor,
    edges_added: list[str],
    edges_removed: list[str],
    fields: set[str],
    cas_version: (int | None) = None
) -> None {
    if self.client is None {
        return;
    }
    _id = str(to_uuid(anchor.id));
    try {
        partial_data: dict[str, object] = Serializer.serialize_fields(anchor, fields)
            if fields
            else {};

        full = dict(Serializer.serialize(anchor, include_type=True));
        non_arch_top = {
            k: v
            for (k, v) in full.items()
            if k not in ('edges', 'archetype', 'version')
        };

        set_doc: dict[str, object] = {
            'type': 'NodeAnchor',
            'updated_at': datetime.now(timezone.utc).isoformat()
        };
        for (k, v) in non_arch_top.items() {
            set_doc[f"data.{k}"] = {'$literal': v};
        }
        for (k, v) in partial_data.items() {
            set_doc[f"data.archetype.{k}"] = {'$literal': v};
        }

        set_doc['data.edges'] = {
            '$let': {
                'vars': {'cur': {'$ifNull': ['$data.edges', []]}},
                'in': {
                    '$concatArrays': [
                        {
                            '$filter': {
                                'input': '$$cur',
                                'as': 'e',
                                'cond': {'$not': [{'$in': ['$$e', edges_removed]}]}
                            }
                        },
                        {
                            '$filter': {
                                'input': edges_added,
                                'as': 'e',
                                'cond': {'$not': [{'$in': ['$$e', '$$cur']}]}
                            }
                        }
                    ]
                }
            }
        };

        set_doc['data.version'] = {'$add': [{'$ifNull': ['$data.version', 0]}, 1]};

        import from pymongo { ReturnDocument }

        cas_filter: dict = {'_id': _id};
        if cas_version is not None {
            if cas_version == 0 {
                cas_filter = {
                    '_id': _id,
                    '$or': [{'data.version': 0}, {'data.version': {'$exists': False}}]
                };
            } else {
                cas_filter = {'_id': _id, 'data.version': cas_version};
            }
        }

        merged_doc = self.collection.find_one_and_update(
            cas_filter,
            [{'$set': set_doc}],
            projection={'data.edges': 1, 'data.version': 1},
            upsert=(cas_version is None),
            return_document=ReturnDocument.AFTER
        );
        if merged_doc is None {
            import from pymongo.errors { DuplicateKeyError }
            existing = self.collection.find_one({'_id': _id}, {'data.version': 1});
            if existing is None and cas_version is not None and cas_version <= 0 {
                try {
                    merged_doc = self.collection.find_one_and_update(
                        {'_id': _id, 'data.version': {'$exists': False}},
                        [{'$set': set_doc}],
                        projection={'data.edges': 1, 'data.version': 1},
                        upsert=True,
                        return_document=ReturnDocument.AFTER
                    );
                } except DuplicateKeyError {
                    raise WriteConflict(
                        anchor_id=anchor.id,
                        expected_version=cas_version,
                        actual_version=0
                    );
                }
            }
            if merged_doc is None {
                actual = -1;
                if existing is not None {
                    actual = existing.get('data', {}).get('version', -1);
                }
                raise WriteConflict(
                    anchor_id=anchor.id,
                    expected_version=cas_version,
                    actual_version=actual
                );
            }
        }

        if self._l2_ref {
            try {
                self._l2_ref.invalidate(anchor.id);

                self._l2_ref.publish_invalidation(str(anchor.id), self._l1_id);
            } except Exception as inv_err {
                logger.debug(
                    f"MongoDB _put_node_atomic L2 invalidation failed: {inv_err}"
                );
            }
        }

        try {
            if merged_doc {
                merged_ids_str: list = merged_doc.get('data', {}).get('edges', [])
                    or [];
                merged_ids: set = {
                    UUID(s)
                    for s in merged_ids_str
                    if s
                };
                object.__setattr__(anchor, '_initial_edge_ids', frozenset(merged_ids));
                anchor.edges = [
                    e
                    for e in anchor.edges
                    if e.id in merged_ids
                ];

                anchor.version = merged_doc.get('data', {}).get(
                    'version', anchor.version + 1
                );
            }
        } except Exception as rb_err {
            logger.debug(f"MongoDB _put_node_atomic read-back failed: {rb_err}");
        }

        anchor.hash = Serializer._compute_hash(anchor);
        try {
            snapshot_field_hashes(anchor);
        } except Exception as shf_err {
            logger.debug(
                f"MongoDB _put_node_atomic _snapshot_field_hashes failed: {shf_err}"
            );
        }
    } except WriteConflict {
        raise;
    } except Exception as e {
        logger.error(f"MongoDB _put_node_atomic failed: {e}");
        raise;
    }
}

impl MongoBackend.batch_get(ids: list[UUID]) -> dict[UUID, Anchor] {
    result: dict[UUID, Anchor] = {};
    if self.client is None or not ids {
        return result;
    }
    self.fetch_count += len(ids);
    str_ids = [str(to_uuid(id)) for id in ids];
    span = start_memory_span(
        "memory.batch_get mongodb",
        {
            "db.system": "mongodb",
            "mem.tier": "L3",
            "mem.op": "batch_get",
            "mem.count": len(ids)
        }
    );
    try {
        for doc in self.collection.find({'_id': {'$in': str_ids}}) {
            if (anchor := self._load_anchor(doc)) {
                anchor.is_updated = False;
                result[UUID(doc['_id'])] = anchor;
            }
        }
    } except Exception as e {
        logger.debug(f"MongoDB batch_get failed: {e}");
    } finally {
        end_memory_span(span);
    }
    return result;
}

impl MongoBackend.reset_counters -> None {
    self.fetch_count = 0;
    self.put_count = 0;
}

impl MongoBackend._load_anchor(raw: dict[(str, Any)]) -> (Anchor | None) {
    if 'data' not in raw {
        return None;
    }
    doc_id = str(raw.get('_id', ''));
    anchor_type = raw.get('type');
    arch_module = raw.get('arch_module');
    arch_type = raw.get('arch_type');
    fingerprint = raw.get('fingerprint');
    fmt_version = raw.get('format_version');
    data = raw['data'];
    try {
        anchor = Serializer.deserialize(data);
    } except Exception as e {
        logger.warning(
            f"MongoBackend: failed to deserialize anchor (id={doc_id}, "
            f"type={anchor_type}): {type(e).__name__}: {e}. "
            "Moving to quarantine."
        );
        _mongo_quarantine(
            self,
            doc_id,
            anchor_type,
            arch_module,
            arch_type,
            fingerprint,
            data,
            f"deserialize error: {type(e).__name__}: {e}",
            from_format_version=fmt_version,
            l2=self._l2_ref,
            reason_code='DESER_ERROR'
        );
        return None;
    }
    if anchor is None {
        cls_resolved = (
            Serializer._get_class(arch_module, arch_type)
                if (arch_module and arch_type)
                else None
        );
        code = 'CLASS_MISSING' if cls_resolved is None else 'FIELD_RECONSTRUCT';
        logger.warning(
            f"MongoBackend: failed to load {arch_module}.{arch_type} "
            f"for anchor {doc_id} ({code}). Moving to quarantine."
        );
        _mongo_quarantine(
            self,
            doc_id,
            anchor_type,
            arch_module,
            arch_type,
            fingerprint,
            data,
            f"load failed for class {arch_module}.{arch_type}",
            from_format_version=fmt_version,
            l2=self._l2_ref,
            reason_code=code
        );
        return None;
    }
    _mongo_persist_repairs(self, doc_id, cast(Anchor, anchor), fingerprint);
    snapshot_field_hashes(cast(Anchor, anchor));
    return cast(Anchor, anchor);
}


def _mongo_attempt_recover(backend: MongoBackend, doc: dict) -> tuple {
    doc_id = str(doc.get('_id', ''));
    data = doc.get('data');
    arch_module = doc.get('arch_module');
    arch_type = doc.get('arch_type');
    if data is None {
        return (False, "no data payload stored");
    }
    try {
        anchor = Serializer.deserialize(data);
    } except Exception as e {
        return (False, f"deserialize raised: {type(e).__name__}: {e}");
    }
    if anchor is None {
        return (False, f"class {arch_module}.{arch_type} still unresolvable");
    }

    re_doc = _anchor_to_doc(cast(Anchor, anchor));
    try {
        backend.collection.update_one({'_id': doc_id}, {'$set': re_doc}, upsert=True);
        _mongo_q_collection(backend).delete_one({'_id': doc_id});
    } except Exception as e {
        return (False, f"write-back failed: {type(e).__name__}: {e}");
    }

    if doc.get('type') == 'EdgeAnchor' and isinstance(data, dict) {
        source_id = data.get('source');
        target_id = data.get('target');
        is_undirected = bool(data.get('is_undirected', False));
        relink_ids: list = [
            n
            for n in [source_id]
            if n
        ];
        if is_undirected and target_id and target_id != source_id {
            relink_ids.append(target_id);
        }
        for node_id in relink_ids {
            try {
                result = backend.collection.update_one(
                    {'_id': node_id, 'type': 'NodeAnchor'},
                    {'$addToSet': {'data.edges': doc_id}}
                );
                if result.matched_count == 0 {
                    logger.warning(
                        f"MongoBackend: recover re-link of edge {doc_id} "
                        f"to node {node_id} skipped: node not live in collection"
                    );
                }
            } except Exception as relink_err {
                logger.warning(
                    f"MongoBackend: recover re-link of edge {doc_id} "
                    f"to node {node_id} failed: {relink_err}"
                );
            }
        }
    }
    return (True, "recovered");
}


def _format_q_doc(d: dict) -> dict {
    return {
        'id': d.get('_id'),
        'type': d.get('type'),
        'arch_module': d.get('arch_module'),
        'arch_type': d.get('arch_type'),
        'fingerprint': d.get('fingerprint'),
        'error': d.get('error'),
        'reason_code': d.get('reason_code'),
        'quarantined_at': d.get('quarantined_at'),
        'from_format_version': d.get('from_format_version'),
        'retry_count': d.get('retry_count'),
        'data': d.get('data')
    };
}


impl MongoBackend.inspect_summary -> dict {
    loc = (
        (self.mongo_url or '<no mongo url>')
        + '/'
        + self.db_name
        + '.'
        + self.collection_name
    );
    if self.client is None {
        return {
            'format_version': '?',
            'anchors_total': 0,
            'anchors_by_type': [],
            'quarantine_total': 0,
            'quarantine_by_type': [],
            'aliases_total': 0,
            'location': loc
        };
    }
    pipeline = [
        {'$group': {'_id': '$arch_type', 'count': {'$sum': 1}}},
        {'$sort': {'count': -1}}
    ];
    try {
        anchors_by = [
            (doc.get('_id') or '<none>', doc.get('count', 0))
            for doc in self.collection.aggregate(pipeline)
        ];
    } except Exception {
        anchors_by = [];
    }
    try {
        qby = [
            (doc.get('_id') or '<none>', doc.get('count', 0))
            for doc in _mongo_q_collection(self).aggregate(pipeline)
        ];
    } except Exception {
        qby = [];
    }
    try {
        alias_count = _mongo_a_collection(self).count_documents({});
    } except Exception {
        alias_count = 0;
    }
    return {
        'format_version': '1',
        'anchors_total': sum(r[1] for r in anchors_by),
        'anchors_by_type': anchors_by,
        'quarantine_total': sum(r[1] for r in qby),
        'quarantine_by_type': qby,
        'aliases_total': alias_count,
        'location': loc
    };
}


impl MongoBackend.list_quarantined(limit: int = 50) -> list {
    if self.client is None {
        return [];
    }
    try {
        docs = list(
            _mongo_q_collection(self).find().sort('quarantined_at', -1).limit(limit)
        );
    } except Exception {
        return [];
    }
    return [
        {
            'id': str(d.get('_id', '')),
            'arch': ((d.get('arch_module') or '?') + '.' + (d.get('arch_type') or '?')),
            'fingerprint': str(d.get('fingerprint') or ''),
            'error': str(d.get('error') or ''),
            'reason_code': str(d.get('reason_code') or ''),
            'quarantined_at': str(d.get('quarantined_at') or '')
        } for d in docs
    ];
}


impl MongoBackend.show_quarantined(id_prefix: str) -> (dict | None) {
    if self.client is None {
        return None;
    }
    try {
        exact = _mongo_q_collection(self).find_one({'_id': id_prefix});
        if exact {
            return _format_q_doc(exact);
        }
        import re;
        pattern = '^' + re.escape(id_prefix);
        docs = list(
            _mongo_q_collection(self).find({'_id': {'$regex': pattern}}).limit(2)
        );
    } except Exception {
        return None;
    }
    if not docs {
        return None;
    }
    if len(docs) > 1 {
        return {'error': 'ambiguous', 'count': len(docs)};
    }
    return _format_q_doc(docs[0]);
}


impl MongoBackend.recover_one(id_prefix: str) -> tuple {
    if self.client is None {
        return (False, "no mongodb connection");
    }
    self._load_db_aliases();
    try {
        exact = _mongo_q_collection(self).find_one({'_id': id_prefix});
        if exact {
            return _mongo_attempt_recover(self, exact);
        }
        import re;
        pattern = '^' + re.escape(id_prefix);
        docs = list(
            _mongo_q_collection(self).find({'_id': {'$regex': pattern}}).limit(2)
        );
    } except Exception as e {
        return (False, f"mongo query failed: {e}");
    }
    if not docs {
        return (False, f"no quarantined row matching {id_prefix}");
    }
    if len(docs) > 1 {
        return (False, f"prefix {id_prefix} matches multiple rows");
    }
    return _mongo_attempt_recover(self, docs[0]);
}


impl MongoBackend.recover_all -> tuple {
    if self.client is None {
        return (0, []);
    }
    self._load_db_aliases();
    try {
        docs = list(_mongo_q_collection(self).find());
    } except Exception {
        return (0, []);
    }

    docs.sort(key=lambda (d) { 0 if d.get('type') == 'NodeAnchor' else 1; });
    recovered = 0;
    still_stuck: list = [];
    for d in docs {
        (ok, reason) = _mongo_attempt_recover(self, d);
        if ok {
            recovered += 1;
        } else {
            still_stuck.append((str(d.get('_id', '')), reason));
        }
    }
    return (recovered, still_stuck);
}


impl MongoBackend.quarantine_dangling(
    missing_id: UUID, referrer_id: (UUID | None), kind: str
) -> None {
    if self.client is None {
        return;
    }
    try {
        q_col = _mongo_q_collection(self);
        now_ts = datetime.now(timezone.utc).isoformat();
        anchor_type = 'EdgeAnchor' if kind == 'edge' else 'NodeAnchor';
        ref_str = str(to_uuid(referrer_id)) if referrer_id is not None else '?';
        mid = str(to_uuid(missing_id));
        err = f"DANGLING_REF: missing {kind} {mid} cited by {ref_str}";
        q_col.update_one(
            {'_id': mid},
            {
                '$set': {
                    'type': anchor_type,
                    'arch_module': None,
                    'arch_type': 'DANGLING_REF',
                    'fingerprint': None,
                    'data': {'referrer': ref_str, 'kind': kind},
                    'error': err,
                    'reason_code': 'DANGLING_REF',
                    'quarantined_at': now_ts,
                    'from_format_version': None
                }
            },
            upsert=True
        );
    } except Exception as e {
        logger.error(f"MongoBackend: failed to record dangling ref {missing_id}: {e}");
    }
}


impl MongoBackend.is_recoverable_quarantine(id: UUID) -> bool {
    if self.client is None {
        return False;
    }
    try {
        return _mongo_q_collection(self).find_one(
            {'_id': str(to_uuid(id)), 'reason_code': {'$ne': 'DANGLING_REF'}},
            {'_id': 1}
        )
            is not None;
    } except Exception {
        return False;
    }
}


impl MongoBackend.fsck(repair: bool = False) -> dict {
    loc = (
        (self.mongo_url or '<no mongo url>')
        + '/'
        + self.db_name
        + '.'
        + self.collection_name
    );
    fsck_report: dict = {
        'location': loc,
        'dangling_node_edge': [],
        'dangling_edge_node': [],
        'orphan_edges': [],
        'orphan_nodes': [],
        'half_linked_edges': [],
        'repaired': repair,
        'repaired_counts': {'pruned': 0, 'quarantined': 0, 'collected': 0}
    };
    if self.client is None {
        return fsck_report;
    }
    node_ids: set[str] = set();
    edge_ids: set[str] = set();
    node_edges: dict[str, list[str]] = {};
    edge_endpoints: dict[str, tuple[(str | None), (str | None)]] = {};
    node_is_root: dict[str, bool] = {};
    try {
        for doc in self.collection.find(
            {}, {'_id': 1, 'type': 1, 'arch_type': 1, 'data': 1}
        ) {
            rid = str(doc.get('_id'));
            rtype = doc.get('type');
            d = doc.get('data') or {};
            if rtype == 'NodeAnchor' {
                node_ids.add(rid);
                node_edges[rid] = [str(e) for e in (d.get('edges') or [])];
                node_is_root[rid] = doc.get('arch_type') == 'Root';
            } elif rtype == 'EdgeAnchor' {
                edge_ids.add(rid);
                src = d.get('source');
                tgt = d.get('target');
                edge_endpoints[rid] = (
                    (str(src) if src is not None else None),
                    (str(tgt) if tgt is not None else None)
                );
            }
        }
    } except Exception as e {
        logger.error(f"MongoBackend.fsck: scan failed: {e}");
        return fsck_report;
    }
    cited_edges: set[str] = set();
    for (nid, eids) in node_edges.items() {
        for eid in eids {
            cited_edges.add(eid);
            if eid not in edge_ids {
                fsck_report['dangling_node_edge'].append((nid, eid));
            }
        }
    }
    referenced_nodes: set[str] = set();
    broken_edge_ids: set[str] = set();
    for (eid, endpoints) in edge_endpoints.items() {
        for endp in endpoints {
            if endp is not None {
                referenced_nodes.add(endp);
                if endp not in node_ids {
                    fsck_report['dangling_edge_node'].append((eid, endp));
                    broken_edge_ids.add(eid);
                }
            }
        }
    }
    orphan_edge_ids: set[str] = set();
    for eid in edge_ids {
        if eid not in cited_edges {
            fsck_report['orphan_edges'].append(eid);
            orphan_edge_ids.add(eid);
        }
    }

    half_linked_ids: set[str] = set();
    for (eid, ep) in edge_endpoints.items() {
        if (
            ep[0] is None
            or ep[1] is None
            or ep[0] not in node_ids
            or ep[1] not in node_ids
        ) {
            continue;
        }
        src = cast(str, ep[0]);
        tgt = cast(str, ep[1]);
        src_cites = src in node_edges and eid in node_edges[src];
        tgt_cites = tgt in node_edges and eid in node_edges[tgt];
        if src_cites != tgt_cites {
            (citing, rejecting) = (src, tgt) if src_cites else (tgt, src);
            fsck_report['half_linked_edges'].append((eid, citing, rejecting));
            half_linked_ids.add(eid);
        }
    }

    collectible_edges: set[str] = orphan_edge_ids | half_linked_ids | broken_edge_ids;
    surviving_referenced: set[str] = set();
    for (eid, ep) in edge_endpoints.items() {
        if eid not in collectible_edges {
            if ep[0] is not None {
                surviving_referenced.add(ep[0]);
            }
            if ep[1] is not None {
                surviving_referenced.add(ep[1]);
            }
        }
    }
    for nid in node_ids {
        remaining = [
            e
            for e in node_edges.get(nid, [])
            if e not in collectible_edges
        ];
        if (
            not node_is_root.get(nid)
            and not remaining
            and nid not in surviving_referenced
        ) {
            fsck_report['orphan_nodes'].append(nid);
        }
    }
    if not repair {
        return fsck_report;
    }
    counts = fsck_report['repaired_counts'];
    try {
        remove_by_node: dict[str, set[str]] = {};
        for (nid, eid) in fsck_report['dangling_node_edge'] {
            remove_by_node.setdefault(nid, set()).add(eid);
            self.quarantine_dangling(to_uuid(eid), to_uuid(nid), 'edge');
            counts['quarantined'] += 1;
        }
        for (eid, nid) in fsck_report['dangling_edge_node'] {
            self.quarantine_dangling(to_uuid(nid), to_uuid(eid), 'node');
            counts['quarantined'] += 1;
        }

        collect_edges: set[str] = broken_edge_ids | orphan_edge_ids | half_linked_ids;
        for (nid, eids) in node_edges.items() {
            also = set(eids) & collect_edges;
            if also {
                remove_by_node.setdefault(nid, set()).update(also);
            }
        }
        for (nid, rem) in remove_by_node.items() {
            self.collection.update_one(
                {'_id': nid}, {'$pullAll': {'data.edges': list(rem)}}
            );
            counts['pruned'] += len(rem);
            if self._l2_ref {
                self._l2_ref.delete(to_uuid(nid));
                self._l2_ref.publish_invalidation(nid, None);
            }
        }
        to_collect: list[str] = list(collect_edges) + list(fsck_report['orphan_nodes']);
        if to_collect {
            res = self.collection.delete_many({'_id': {'$in': to_collect}});
            counts['collected'] += res.deleted_count or 0;
            if self._l2_ref {
                for cid in to_collect {
                    self._l2_ref.delete(to_uuid(cid));
                    self._l2_ref.publish_invalidation(cid, None);
                }
            }
        }
    } except Exception as e {
        logger.error(f"MongoBackend.fsck: repair failed: {e}");
        fsck_report['repaired'] = False;
    }
    return fsck_report;
}


impl MongoBackend._auto_retry_quarantine(limit: int = 500) -> tuple {
    import from jaclang.runtimelib.schema_rules { merged_rules_for, repair_mode }
    if self.client is None or repair_mode() == 'off' {
        return (0, 0);
    }
    try {
        docs = list(
            _mongo_q_collection(self).find(
                {
                    '$or': [
                        {'retry_count': {'$exists': False}},
                        {'retry_count': {'$lt': 5}}
                    ]
                }
            ).limit(
                limit
            )
        );
    } except Exception as e {
        logger.debug(f"MongoBackend: quarantine auto-retry scan failed: {e}");
        return (0, 0);
    }
    if not docs {
        return (0, 0);
    }

    docs.sort(key=lambda (d) { 0 if d.get('type') == 'NodeAnchor' else 1; });
    attempted = 0;
    recovered = 0;
    for d in docs {
        cls = Serializer._get_class(d.get('arch_module'), d.get('arch_type'));
        if cls is None {
            continue;
        }
        code = d.get('reason_code');
        if not (
            code == 'CLASS_MISSING'
            or code == 'CASCADE'
            or merged_rules_for(cls) is not None
        ) {
            continue;
        }
        attempted += 1;
        (ok, reason) = _mongo_attempt_recover(self, d);
        if ok {
            recovered += 1;
        } else {
            doc_id = str(d.get('_id', ''));
            try {
                _mongo_q_collection(self).update_one(
                    {'_id': doc_id}, {'$inc': {'retry_count': 1}}
                );
            } except Exception { }
            retries = int(d.get('retry_count') or 0) + 1;
            if retries >= 5 {
                logger.warning(
                    f"MongoBackend: quarantined doc {doc_id} still failing "
                    f"after {retries} auto-retries ({reason}); giving up "
                    "until `jac db recover` is run manually."
                );
            }
        }
    }
    if attempted {
        logger.info(
            f"MongoBackend: quarantine auto-retry attempted {attempted}, "
            f"recovered {recovered} (of {len(docs)} scanned)."
        );
    }
    return (attempted, recovered);
}


impl MongoBackend.list_aliases -> list {
    if self.client is None {
        return [];
    }
    try {
        docs = list(_mongo_a_collection(self).find().sort('created_at', 1));
    } except Exception {
        return [];
    }
    return [
        {
            'old_name': str(d.get('_id', '')),
            'new_name': str(d.get('new_name', '')),
            'created_at': str(d.get('created_at', ''))
        } for d in docs
    ];
}


impl MongoBackend.add_alias(old_name: str, new_name: str) -> None {
    if self.client is None {
        return;
    }
    now = datetime.now(timezone.utc).isoformat();
    try {
        _mongo_a_collection(self).update_one(
            {'_id': old_name},
            {'$set': {'new_name': new_name, 'created_at': now}},
            upsert=True
        );
    } except Exception as e {
        logger.error(f"MongoBackend: add_alias failed: {e}");
        return;
    }
    Serializer._aliases[old_name] = new_name;
}


impl MongoBackend.remove_alias(old_name: str) -> bool {
    if self.client is None {
        return False;
    }
    try {
        result = _mongo_a_collection(self).delete_one({'_id': old_name});
    } except Exception as e {
        logger.error(f"MongoBackend: remove_alias failed: {e}");
        return False;
    }
    removed = result.deleted_count > 0;
    if removed {
        Serializer._aliases.pop(old_name, None);
    }
    return removed;
}


impl MongoBackend.aget(id: UUID) -> (Anchor | None) {
    import from jaclang.scale._optdeps.pymongo { AsyncMongoClient }
    if AsyncMongoClient is None or self.mongo_url is None {
        return await super.aget(id);
    }
    if 'async_mongo_client' not in _process_cache {
        _process_cache['async_mongo_client'] = AsyncMongoClient(self.mongo_url);
    }
    coll = _process_cache['async_mongo_client'][self.db_name][self.collection_name];
    span = start_memory_span(
        "memory.get mongodb",
        {"db.system": "mongodb", "mem.tier": "L3", "mem.op": "get"}
    );
    try {
        db_obj = await coll.find_one({'_id': str(to_uuid(id))});
        if not db_obj {
            return None;
        }
        return self._load_anchor(db_obj);
    } except Exception as e {
        logger.debug(f"Async aget failed: {e}");
        return None;
    } finally {
        end_memory_span(span);
    }
}

impl MongoBackend.aput(anchor: Anchor) -> None { }

impl MongoBackend._load_db_aliases -> int {
    if self.client is None {
        return 0;
    }
    count = 0;
    try {
        for doc in _mongo_a_collection(self).find() {
            old_name = doc.get('_id');
            new_name = doc.get('new_name');
            if isinstance(old_name, str) and isinstance(new_name, str) {
                Serializer._aliases[old_name] = new_name;
                count += 1;
            }
        }
    } except Exception as e {
        logger.debug(f"MongoBackend: _load_db_aliases skipped: {e}");
    }
    return count;
}
