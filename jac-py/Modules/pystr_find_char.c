/* Header-free extract: first index of char in NUL-terminated string; -1 if absent. */

int
pystr_find_char(const char *s, int ch)
{
    int i;
    if (s == 0) {
        return -1;
    }
    i = 0;
    while (s[i] != 0) {
        if ((unsigned char)s[i] == (unsigned char)ch) {
            return i;
        }
        i += 1;
    }
    return -1;
}
