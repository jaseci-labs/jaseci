"""TTG (Temporal Trace Graph) prefetch generator for the Postgres runtime."""

import jaclang.compiler.frontend.unitree as uni;
import from uuid { UUID }

import from jaclang.runtime.archetype { NodeAnchor, NodeArchetype, VisitType }
import from jaclang.runtime.graph_query { QHop }

class JacTTGGenerator {
    @classmethod
    def _resolve_type_name(
        cls: type[JacTTGGenerator], ref: (type | str | None)
    ) -> (str | None);

    @classmethod
    def _runtime_type_for_name(
        cls: type[JacTTGGenerator], warch: any, name: (str | type | None)
    ) -> (type | None);

    @classmethod
    def _find_walker_ast_node(
        cls: type[JacTTGGenerator], warch_cls: type
    ) -> (uni.Archetype | None);

    @classmethod
    def _resolve_archetype(
        cls: type[JacTTGGenerator], scope_src: any, name: str
    ) -> (uni.Archetype | None);

    @classmethod
    def _extract_edge_step(
        cls: type[JacTTGGenerator], scope: any, item: any
    ) -> tuple[str | None, str | None, int];

    @classmethod
    def _edge_ref_explicit_origin_name(
        cls: type[JacTTGGenerator], trailer: any
    ) -> (str | None);

    @classmethod
    def _edge_ref_origin_is_current(
        cls: type[JacTTGGenerator], trailer: any
    ) -> bool;

    @classmethod
    def _extract_chains_from_trailer(
        cls: type[JacTTGGenerator], scope: any, trailer: any
    ) -> list[tuple[str | None, str | None, int]];

    @classmethod
    def _extract_refs_from_body(
        cls: type[JacTTGGenerator], body: any
    ) -> list[list[tuple[str | None, str | None, int]]];

    @classmethod
    def _ability_sub_nodes(
        cls: type[JacTTGGenerator], ability: uni.Ability, node_type: type
    ) -> list;

    @classmethod
    def _ast_type_name(
        cls: type[JacTTGGenerator], expr: (uni.UniNode | None)
    ) -> (str | None);

    @classmethod
    def _call_target_symbol(
        cls: type[JacTTGGenerator], call: uni.FuncCall
    ) -> (uni.Symbol | None);

    @classmethod
    def _resolve_called_ability(
        cls: type[JacTTGGenerator], call: uni.FuncCall
    ) -> (uni.Ability | None);

    @classmethod
    def _single_param_node_type(
        cls: type[JacTTGGenerator], ability: uni.Ability
    ) -> (str | None);

    @classmethod
    def _trace_method_calls(
        cls: type[JacTTGGenerator],
        ability: uni.Ability,
        current_node_type: (str | None) = None,
        seen: (set[int] | None) = None
    ) -> list[VisitType];

    @classmethod
    def _extract_visits_from_ast(
        cls: type[JacTTGGenerator], warch: any
    ) -> list[VisitType];

    @classmethod
    def _origin_for_id(cls: type[JacTTGGenerator], id: UUID) -> NodeArchetype;

    @classmethod
    def _arch_types_for_ids(
        cls: type[JacTTGGenerator], mem: any, ids: list[UUID]
    ) -> dict[UUID, str];

    @classmethod
    def _chain_to_hops(
        cls: type[JacTTGGenerator],
        warch: any,
        chain: list[tuple[str | None, str | None, int]]
    ) -> list[QHop];

    @classmethod
    def _resolve_chain_ids(
        cls: type[JacTTGGenerator],
        mem: any,
        warch: any,
        origin_id: UUID,
        chain: list[tuple[str | None, str | None, int]],
        limit: int
    ) -> list[UUID];

    @classmethod
    def get_ttg_prefetch_list(
        cls: type[JacTTGGenerator],
        warch: any,
        start_anchor: NodeAnchor,
        mem: any = None,
        max_length: int = 200
    ) -> list[UUID];
}
