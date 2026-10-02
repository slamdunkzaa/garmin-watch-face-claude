// Copies a file into GARMIN/Apps on a Garmin watch connected in MTP mode.
#include <libmtp.h>
#include <libgen.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/stat.h>

// Returns the id of the entry called name inside parent, or 0 if missing.
static uint32_t find_child(LIBMTP_mtpdevice_t *device, uint32_t storage, uint32_t parent, const char *name) {
    uint32_t id = 0;
    LIBMTP_file_t *files = LIBMTP_Get_Files_And_Folders(device, storage, parent);
    while (files != NULL) {
        LIBMTP_file_t *next = files->next;
        if (id == 0 && files->filename != NULL && strcasecmp(files->filename, name) == 0) {
            id = files->item_id;
        }
        LIBMTP_destroy_file_t(files);
        files = next;
    }
    return id;
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: %s file.prg\n", argv[0]);
        return 2;
    }
    struct stat st;
    if (stat(argv[1], &st) != 0) {
        perror(argv[1]);
        return 1;
    }
    char *name = basename(argv[1]);

    LIBMTP_Init();
    LIBMTP_raw_device_t *raw = NULL;
    int count = 0;
    if (LIBMTP_Detect_Raw_Devices(&raw, &count) != LIBMTP_ERROR_NONE || count == 0) {
        fprintf(stderr, "No MTP device found. Is the watch connected and in MTP mode?\n");
        return 1;
    }
    LIBMTP_mtpdevice_t *device = LIBMTP_Open_Raw_Device_Uncached(&raw[0]);
    if (device == NULL) {
        fprintf(stderr, "Could not open the device.\n");
        return 1;
    }
    if (device->storage == NULL) {
        fprintf(stderr, "Device has no storage.\n");
        return 1;
    }
    uint32_t storage = device->storage->id;

    uint32_t garmin = find_child(device, storage, LIBMTP_FILES_AND_FOLDERS_ROOT, "GARMIN");
    uint32_t apps = garmin ? find_child(device, storage, garmin, "Apps") : 0;
    if (apps == 0) {
        fprintf(stderr, "GARMIN/Apps not found on the device.\n");
        LIBMTP_Release_Device(device);
        return 1;
    }

    uint32_t existing = find_child(device, storage, apps, name);
    if (existing != 0) {
        printf("Replacing existing %s\n", name);
        if (LIBMTP_Delete_Object(device, existing) != 0) {
            LIBMTP_Dump_Errorstack(device);
            LIBMTP_Release_Device(device);
            return 1;
        }
    }

    LIBMTP_file_t *file = LIBMTP_new_file_t();
    file->filename = strdup(name);
    file->filesize = (uint64_t) st.st_size;
    file->filetype = LIBMTP_FILETYPE_UNKNOWN;
    file->parent_id = apps;
    file->storage_id = storage;

    int result = LIBMTP_Send_File_From_File(device, argv[1], file, NULL, NULL);
    if (result != 0) {
        LIBMTP_Dump_Errorstack(device);
    } else {
        printf("Sent %s to GARMIN/Apps (%lld bytes)\n", name, (long long) st.st_size);
    }
    LIBMTP_destroy_file_t(file);
    LIBMTP_Release_Device(device);
    return result != 0;
}
