#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char *command_name(const char *path) {
    const char *slash = strrchr(path, '/');
    return slash ? slash + 1 : path;
}

static void append_file(const char *source_path, const char *destination_path) {
    FILE *source = fopen(source_path, "rb");
    FILE *destination = fopen(destination_path, "ab");
    if (!source || !destination) {
        if (source) fclose(source);
        if (destination) fclose(destination);
        return;
    }

    char buffer[4096];
    size_t count;
    while ((count = fread(buffer, 1, sizeof(buffer), source)) > 0) {
        fwrite(buffer, 1, count, destination);
    }
    fclose(source);
    fclose(destination);
}

static int configured_exit_code(const char *name) {
    char key[128] = "CODEX_DONE_STUB_";
    size_t offset = strlen(key);
    for (const char *character = name; *character && offset + 6 < sizeof(key); character++) {
        key[offset++] = (char)toupper((unsigned char)*character);
    }
    strcpy(key + offset, "_EXIT");

    const char *value = getenv(key);
    return value ? atoi(value) : 0;
}

int main(int argc, char **argv) {
    const char *name = command_name(argv[0]);
    const char *log_directory = getenv("CODEX_DONE_TEST_LOG");
    if (!log_directory) {
        return configured_exit_code(name);
    }

    char log_path[4096];
    snprintf(log_path, sizeof(log_path), "%s/%s.log", log_directory, name);
    FILE *log = fopen(log_path, "ab");
    if (log) {
        for (int index = 1; index < argc; index++) {
            if (index > 1) fputc(' ', log);
            fputs(argv[index], log);
        }
        fputc('\n', log);
        fclose(log);
    }

    if (strcmp(name, "curl") == 0) {
        const char *output_path = NULL;
        const char *payload_path = NULL;
        for (int index = 1; index + 1 < argc; index++) {
            if (strcmp(argv[index], "--output") == 0) {
                output_path = argv[index + 1];
            } else if (strcmp(argv[index], "--data-binary") == 0 && argv[index + 1][0] == '@') {
                payload_path = argv[index + 1] + 1;
            }
        }

        if (payload_path) {
            char payload_log_path[4096];
            snprintf(payload_log_path, sizeof(payload_log_path), "%s/openai-payload.log", log_directory);
            append_file(payload_path, payload_log_path);
        }
        if (output_path) {
            FILE *output = fopen(output_path, "wb");
            if (output) {
                fputs("fake audio", output);
                fclose(output);
            }
        }
    }

    return configured_exit_code(name);
}
