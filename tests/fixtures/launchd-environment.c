#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static void print_variable(const char *name)
{
    const char *value = getenv(name);

    printf("%s%s%s%c", name, value == NULL ? "" : "=",
           value == NULL ? "" : value, '\0');
}

int main(int argc, char **argv)
{
    printf("%ld%c", (long)getpid(), '\0');

    for (int i = 0; i < argc; i++) {
        printf("%s%c", argv[i], '\0');
    }

    print_variable("NIX_SSL_CERT_FILE");
    print_variable("SSL_CERT_FILE");

    /* Check that the launcher preserves a nonzero exit status, too. */
    return 23;
}
