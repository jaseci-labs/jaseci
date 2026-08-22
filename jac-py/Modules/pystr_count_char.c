/* Header-free extract: count occurrences of char in NUL-terminated string. */

unsigned long
pystr_count_char(const char *s, int ch)
{
    unsigned long n;
    unsigned long i;
    if (s == 0) {
        return 0;
    }
    n = 0;
    i = 0;
    while (s[i] != 0) {
        if ((unsigned char)s[i] == (unsigned char)ch) {
            n += 1;
        }
        i += 1;
    }
    return n;
}
