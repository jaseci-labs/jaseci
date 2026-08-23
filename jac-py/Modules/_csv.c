/* Header-free extract: _csv parser/writer/dialect kernels.
 *
 * Source: CPython 3.14.6 Modules/_csv.c (pinned reference).
 * Slices: the reader character state machine (parse_process_char across
 * START_RECORD..EAT_CRNL incl. escaped CRNL and strict quote-in-quoted
 * handling), the end-of-input record verdict from Reader_iternext
 * ("unexpected end of data" vs final save_field), dialect validation
 * (dialect_check_quoting / dialect_check_char / dialect_check_chars with
 * the NOT_SET sentinel and lineterminator membership search), and the
 * writer join_append_data per-character quoting/escape machine plus the
 * QUOTE_* quoted-flag switch and empty-field guards.
 *
 * The PyObject glue (Reader/Writer/Dialect heap types, module state,
 * field list building, float()/str() conversions, the .write() call,
 * PyArg parsing) stays in the product facade
 * (jac-py/jacpython/_csvmodule.jac); these kernels carry the integer
 * control-state machines verbatim so they can be differentially lifted
 * and ratcheted by c2jac.
 *
 * Characters are modeled as unsigned ints with the C sentinels NOT_SET
 * and EOL kept verbatim; mutable reader/writer state crosses the kernel
 * boundary by value in small structs (the proven c2jac-lowerable
 * shape), with action/status codes standing in for PyErr_Format paths
 * so the facade can raise byte-exact messages. The parse_process_char
 * switch is spelled as state-keyed if chains because its two legal
 * fall-throughs (START_RECORD -> START_FIELD,
 * AFTER_ESCAPED_CRNL -> IN_FIELD) duplicate their target bodies here;
 * transitions are otherwise verbatim.
 */

typedef long Py_ssize_t; /* LP64, mirrors jacport.h */

#define PY_SSIZE_T_MAX ((Py_ssize_t)9223372036854775807L)

#define NOT_SET ((unsigned int)-1)
#define EOL ((unsigned int)-2)

/* ParserState (Modules/_csv.c). */
#define ST_START_RECORD 0
#define ST_START_FIELD 1
#define ST_ESCAPED_CHAR 2
#define ST_IN_FIELD 3
#define ST_IN_QUOTED_FIELD 4
#define ST_ESCAPE_IN_QUOTED_FIELD 5
#define ST_QUOTE_IN_QUOTED_FIELD 6
#define ST_EAT_CRNL 7
#define ST_AFTER_ESCAPED_CRNL 8

/* QuoteStyle (Modules/_csv.c). */
#define QUOTE_MINIMAL 0
#define QUOTE_ALL 1
#define QUOTE_NONNUMERIC 2
#define QUOTE_NONE 3
#define QUOTE_STRINGS 4
#define QUOTE_NOTNULL 5

/* parse_process_char status codes; the facade maps each to its exact
 * csv.Error message. */
#define CSV_PARSE_OK 0
#define CSV_PARSE_ERR_FIELD_LIMIT (-1) /* "field larger than field limit (%zd)" */
#define CSV_PARSE_ERR_EXPECTED (-2)    /* "'%c' expected after '%c'" */
#define CSV_PARSE_ERR_NEWLINE (-3)     /* "new-line character seen ..." */

/* parse_process_char step actions for the caller (field buffer owner). */
#define CSV_ACT_NONE 0     /* pure state transition */
#define CSV_ACT_APPEND 1   /* append step.emit to the current field */
#define CSV_ACT_SAVE 2     /* save the current field (already terminated) */

typedef struct csv_parse_step {
    int state;             /* updated ParserState */
    int unquoted_field;    /* updated flag */
    Py_ssize_t field_len;  /* updated current-field length */
    int action;            /* CSV_ACT_* */
    unsigned int emit;     /* character for CSV_ACT_APPEND */
    int status;            /* CSV_PARSE_* */
} csv_parse_step;

/* Dialect knobs the reader machine reads (subset of DialectObj). */
typedef struct csv_dialect_cfg {
    int quoting;
    int doublequote;
    int skipinitialspace;
    int strict;
    unsigned int delimiter;
    unsigned int quotechar;
    unsigned int escapechar;
} csv_dialect_cfg;

static int
csv_in_chars(unsigned int c, const unsigned int *set, Py_ssize_t set_len)
{
    Py_ssize_t i;
    for (i = 0; i < set_len; i++) {
        if (set[i] == c)
            return 1;
    }
    return 0;
}

/* parse_save_field() factored to its None-vs-string branch: returns 1
 * when the saved value is None (empty unquoted field under
 * QUOTE_NOTNULL/QUOTE_STRINGS), 0 for a string value. The caller owns
 * float() conversion for unquoted non-empty fields under
 * QUOTE_NONNUMERIC/QUOTE_STRINGS. */
int
csv_parse_save_is_none(int unquoted_field, Py_ssize_t field_len, int quoting)
{
    if (unquoted_field && field_len == 0 &&
        (quoting == QUOTE_NOTNULL || quoting == QUOTE_STRINGS))
        return 1;
    return 0;
}

/* One iteration of the parse_process_char() switch. Field-buffer
 * growth and the field_size_limit check are expressed through
 * field_len >= field_limit -> CSV_PARSE_ERR_FIELD_LIMIT, mirroring
 * parse_add_char's guard. */
csv_parse_step
csv_parse_process_char(int state, int unquoted_field, Py_ssize_t field_len,
                       csv_dialect_cfg dia, Py_ssize_t field_limit,
                       unsigned int c)
{
    csv_parse_step r;
    r.state = state;
    r.unquoted_field = unquoted_field;
    r.field_len = field_len;
    r.action = CSV_ACT_NONE;
    r.emit = 0;
    r.status = CSV_PARSE_OK;

    /* START_RECORD falls through into START_FIELD for a normal first
     * character; AFTER_ESCAPED_CRNL falls through into IN_FIELD for a
     * non-EOL character. Both fall-throughs are duplicated inline. */
    if (state == ST_START_RECORD) {
        if (c == EOL) {
            return r; /* empty line - return [] */
        }
        if (c == '\n' || c == '\r') {
            r.state = ST_EAT_CRNL;
            return r;
        }
        state = ST_START_FIELD;
        unquoted_field = r.unquoted_field;
    }

    if (state == ST_START_FIELD) {
        /* expecting field */
        r.state = ST_START_FIELD;
        r.unquoted_field = 1;
        if (c == '\n' || c == '\r' || c == EOL) {
            /* save empty field - return [fields] */
            r.action = CSV_ACT_SAVE;
            if (c == EOL)
                r.state = ST_START_RECORD;
            else
                r.state = ST_EAT_CRNL;
        }
        else if (c == dia.quotechar && dia.quoting != QUOTE_NONE) {
            /* start quoted field */
            r.unquoted_field = 0;
            r.state = ST_IN_QUOTED_FIELD;
        }
        else if (c == dia.escapechar) {
            /* possible escaped character */
            r.state = ST_ESCAPED_CHAR;
        }
        else if (c == ' ' && dia.skipinitialspace) {
            /* ignore spaces at start of field */
        }
        else if (c == dia.delimiter) {
            /* save empty field */
            r.action = CSV_ACT_SAVE;
        }
        else {
            /* begin new unquoted field (parse_add_char guard) */
            if (field_len >= field_limit) {
                r.status = CSV_PARSE_ERR_FIELD_LIMIT;
                return r;
            }
            r.action = CSV_ACT_APPEND;
            r.emit = c;
            r.field_len = field_len + 1;
            r.state = ST_IN_FIELD;
        }
        return r;
    }

    if (state == ST_ESCAPED_CHAR) {
        if (c == '\n' || c == '\r') {
            if (field_len >= field_limit) {
                r.status = CSV_PARSE_ERR_FIELD_LIMIT;
                return r;
            }
            r.action = CSV_ACT_APPEND;
            r.emit = c;
            r.field_len = field_len + 1;
            r.state = ST_AFTER_ESCAPED_CRNL;
            return r;
        }
        if (c == EOL)
            c = '\n';
        if (field_len >= field_limit) {
            r.status = CSV_PARSE_ERR_FIELD_LIMIT;
            return r;
        }
        r.action = CSV_ACT_APPEND;
        r.emit = c;
        r.field_len = field_len + 1;
        r.state = ST_IN_FIELD;
        return r;
    }

    if (state == ST_AFTER_ESCAPED_CRNL && c == EOL)
        return r;

    if (state == ST_AFTER_ESCAPED_CRNL || state == ST_IN_FIELD) {
        /* in unquoted field */
        if (c == '\n' || c == '\r' || c == EOL) {
            /* end of line - return [fields] */
            r.action = CSV_ACT_SAVE;
            if (c == EOL)
                r.state = ST_START_RECORD;
            else
                r.state = ST_EAT_CRNL;
        }
        else if (c == dia.escapechar) {
            /* possible escaped character */
            r.state = ST_ESCAPED_CHAR;
        }
        else if (c == dia.delimiter) {
            /* save field - wait for new field */
            r.action = CSV_ACT_SAVE;
            r.state = ST_START_FIELD;
        }
        else {
            /* normal character - save in field */
            if (field_len >= field_limit) {
                r.status = CSV_PARSE_ERR_FIELD_LIMIT;
                return r;
            }
            r.action = CSV_ACT_APPEND;
            r.emit = c;
            r.field_len = field_len + 1;
        }
        return r;
    }

    if (state == ST_IN_QUOTED_FIELD) {
        /* in quoted field */
        if (c == EOL) {
            /* embedded newline */
        }
        else if (c == dia.escapechar) {
            /* Possible escape character */
            r.state = ST_ESCAPE_IN_QUOTED_FIELD;
        }
        else if (c == dia.quotechar && dia.quoting != QUOTE_NONE) {
            if (dia.doublequote) {
                /* doublequote; " represented by "" */
                r.state = ST_QUOTE_IN_QUOTED_FIELD;
            }
            else {
                /* end of quote part of field */
                r.state = ST_IN_FIELD;
            }
        }
        else {
            /* normal character - save in field */
            if (field_len >= field_limit) {
                r.status = CSV_PARSE_ERR_FIELD_LIMIT;
                return r;
            }
            r.action = CSV_ACT_APPEND;
            r.emit = c;
            r.field_len = field_len + 1;
        }
        return r;
    }

    if (state == ST_ESCAPE_IN_QUOTED_FIELD) {
        if (c == EOL)
            c = '\n';
        if (field_len >= field_limit) {
            r.status = CSV_PARSE_ERR_FIELD_LIMIT;
            return r;
        }
        r.action = CSV_ACT_APPEND;
        r.emit = c;
        r.field_len = field_len + 1;
        r.state = ST_IN_QUOTED_FIELD;
        return r;
    }

    if (state == ST_QUOTE_IN_QUOTED_FIELD) {
        /* doublequote - seen a quote in a quoted field */
        if (dia.quoting != QUOTE_NONE && c == dia.quotechar) {
            /* save "" as " */
            if (field_len >= field_limit) {
                r.status = CSV_PARSE_ERR_FIELD_LIMIT;
                return r;
            }
            r.action = CSV_ACT_APPEND;
            r.emit = c;
            r.field_len = field_len + 1;
            r.state = ST_IN_QUOTED_FIELD;
        }
        else if (c == dia.delimiter) {
            /* save field - wait for new field */
            r.action = CSV_ACT_SAVE;
            r.state = ST_START_FIELD;
        }
        else if (c == '\n' || c == '\r' || c == EOL) {
            /* end of line - return [fields] */
            r.action = CSV_ACT_SAVE;
            if (c == EOL)
                r.state = ST_START_RECORD;
            else
                r.state = ST_EAT_CRNL;
        }
        else if (!dia.strict) {
            if (field_len >= field_limit) {
                r.status = CSV_PARSE_ERR_FIELD_LIMIT;
                return r;
            }
            r.action = CSV_ACT_APPEND;
            r.emit = c;
            r.field_len = field_len + 1;
            r.state = ST_IN_FIELD;
        }
        else {
            /* illegal */
            r.status = CSV_PARSE_ERR_EXPECTED;
        }
        return r;
    }

    if (state == ST_EAT_CRNL) {
        if (c == '\n' || c == '\r') {
            /* eat it */
        }
        else if (c == EOL)
            r.state = ST_START_RECORD;
        else {
            /* "new-line character seen in unquoted field ..." */
            r.status = CSV_PARSE_ERR_NEWLINE;
        }
        return r;
    }
    return r;
}

/* End-of-input verdict of Reader_iternext_lock_held: what happens when
 * the input iterator raises StopIteration mid-record. */
#define CSV_EOF_STOP 0       /* StopIteration propagates (record done) */
#define CSV_EOF_ERROR 1      /* strict: "unexpected end of data" */
#define CSV_EOF_SAVE 2       /* save trailing partial field, finish record */

int
csv_reader_eof_verdict(int state, int field_len_nonzero, int strict)
{
    if (field_len_nonzero || state == ST_IN_QUOTED_FIELD) {
        if (strict)
            return CSV_EOF_ERROR;
        return CSV_EOF_SAVE;
    }
    return CSV_EOF_STOP;
}

/* ---------------------------------------------------------------------------
 * Dialect validation
 */

/* dialect_check_quoting(): 0 valid, -1 TypeError bad "quoting" value. */
int
csv_check_quoting(int quoting)
{
    if (quoting >= QUOTE_MINIMAL && quoting <= QUOTE_NOTNULL)
        return 0;
    return -1;
}

/* dialect_check_char() status codes. */
#define CSV_CHAR_OK 0
#define CSV_CHAR_BAD_VALUE (-1)         /* ValueError "bad %s value" */
#define CSV_CHAR_BAD_LINETERM (-2)      /* ValueError "bad %s or lineterminator value" */

int
csv_dialect_check_char(unsigned int c, int allowspace,
                       const unsigned int *lineterm, Py_ssize_t lineterm_len)
{
    if (c == '\r' || c == '\n' || (c == ' ' && !allowspace))
        return CSV_CHAR_BAD_VALUE;
    if (csv_in_chars(c, lineterm, lineterm_len))
        return CSV_CHAR_BAD_LINETERM;
    return CSV_CHAR_OK;
}

/* dialect_check_chars(): 0 valid, -1 ValueError "bad %s or %s value". */
int
csv_dialect_check_chars(unsigned int c1, unsigned int c2)
{
    if (c1 == c2 && c1 != NOT_SET)
        return -1;
    return 0;
}

/* ---------------------------------------------------------------------------
 * Writer join machine
 */

/* join_append_data status codes. */
#define CSV_JOIN_OK 0
#define CSV_JOIN_ERR_NOESCAPE (-1) /* "need to escape, but no escapechar set" */

typedef struct csv_join_step {
    Py_ssize_t rec_len;   /* updated running record length */
    int quoted;           /* updated quoting flag */
    int n_emit;           /* characters this step contributes (1 or 2) */
    unsigned int emit0;   /* leading extra char (escapechar/doubled quote) */
    unsigned int emit1;   /* the field character itself */
    int status;           /* CSV_JOIN_* */
} csv_join_step;

/* One field-character iteration of join_append_data(). The caller
 * handles the inter-field delimiter and the enclosing quotes implied
 * by the returned quoted flag; want_escape bookkeeping, doublequote
 * doubling and the no-escapechar error are carried here verbatim.
 * in_lineterm must report membership of c in dialect->lineterminator. */
csv_join_step
csv_join_char_step(Py_ssize_t rec_len, int quoted, int quoting,
                   int doublequote, unsigned int delimiter,
                   unsigned int quotechar, unsigned int escapechar,
                   int in_lineterm, unsigned int c)
{
    csv_join_step r;
    int want_escape = 0;
    r.rec_len = rec_len;
    r.quoted = quoted;
    r.n_emit = 1;
    r.emit0 = 0;
    r.emit1 = c;
    r.status = CSV_JOIN_OK;

    if (c == delimiter || c == escapechar || c == quotechar ||
        c == '\n' || c == '\r' || in_lineterm) {
        if (quoting == QUOTE_NONE)
            want_escape = 1;
        else {
            if (c == quotechar) {
                if (doublequote) {
                    r.rec_len = rec_len + 1;
                    r.emit0 = quotechar;
                    r.n_emit = 2;
                }
                else
                    want_escape = 1;
            }
            else if (c == escapechar) {
                want_escape = 1;
            }
            if (!want_escape)
                r.quoted = 1;
        }
        if (want_escape) {
            if (escapechar == NOT_SET) {
                r.status = CSV_JOIN_ERR_NOESCAPE;
                return r;
            }
            r.rec_len = rec_len + 1;
            r.emit0 = escapechar;
            r.n_emit = 2;
        }
    }
    r.rec_len = r.rec_len + 1;
    return r;
}

/* The quoting switch of csv_writerow_lock_held: initial quoted flag for
 * one field. is_number mirrors PyNumber_Check(field) (nb_float/nb_index
 * providers only), is_str mirrors PyUnicode_Check, is_none mirrors
 * field == Py_None. */
int
csv_writer_quoted_flag(int quoting, int is_number, int is_str, int is_none)
{
    if (quoting == QUOTE_NONNUMERIC)
        return !is_number;
    if (quoting == QUOTE_ALL)
        return 1;
    if (quoting == QUOTE_STRINGS)
        return is_str;
    if (quoting == QUOTE_NOTNULL)
        return !is_none;
    return 0;
}

/* join_append()'s empty-field guard for a space delimiter with
 * skipinitialspace: 0 = proceed unchanged, 1 = force-quote the empty
 * field, 2 = raise "empty field must be quoted if delimiter is a space
 * and skipinitialspace is true". */
int
csv_join_empty_space_guard(int field_len_nonzero, int null_field, int quoting,
                           int delimiter_is_space, int skipinitialspace)
{
    if (!field_len_nonzero && delimiter_is_space && skipinitialspace) {
        if (quoting == QUOTE_NONE ||
            (null_field && (quoting == QUOTE_STRINGS ||
                            quoting == QUOTE_NOTNULL)))
            return 2;
        return 1;
    }
    return 0;
}

/* csv_writerow_lock_held()'s post-loop guard for an all-empty record:
 * 0 = nothing to do, 1 = re-append a single quoted NULL field, 2 =
 * raise "single empty field record must be quoted". */
int
csv_join_empty_record_guard(int num_fields, Py_ssize_t rec_len, int null_field,
                            int quoting)
{
    if (num_fields > 0 && rec_len == 0) {
        if (quoting == QUOTE_NONE ||
            (null_field && (quoting == QUOTE_STRINGS ||
                            quoting == QUOTE_NOTNULL)))
            return 2;
        return 1;
    }
    return 0;
}
