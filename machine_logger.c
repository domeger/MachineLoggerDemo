#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>

#define BUFFER_SIZE 4096
#define TEST_FILE "/mnt/encrypted/io_test.dat"
#define METRICS_FILE "/var/log/disk_metrics.txt"

// Structure to hold metrics
struct IOMetrics {
    long bytes_read;
    long bytes_written;
    long read_time_us;
    long write_time_us;
    int read_errors;
    int write_errors;
};

void write_metrics(struct IOMetrics *metrics) {
    FILE *file = fopen(METRICS_FILE, "w");
    if (file != NULL) {
        fprintf(file, "disk_bytes_read %ld\n", metrics->bytes_read);
        fprintf(file, "disk_bytes_written %ld\n", metrics->bytes_written);
        fprintf(file, "disk_read_time_microseconds %ld\n", metrics->read_time_us);
        fprintf(file, "disk_write_time_microseconds %ld\n", metrics->write_time_us);
        fprintf(file, "disk_read_errors %d\n", metrics->read_errors);
        fprintf(file, "disk_write_errors %d\n", metrics->write_errors);
        fclose(file);
    }
}

int main() {
    FILE *file;
    char buffer[BUFFER_SIZE];
    struct timespec start, end;
    struct IOMetrics metrics = {0};
    
    printf("Starting I/O monitoring...\n");

    while (1) {
        // Write operation
        clock_gettime(CLOCK_MONOTONIC, &start);
        file = fopen(TEST_FILE, "a");
        if (file == NULL) {
            metrics.write_errors++;
        } else {
            size_t bytes = fwrite(buffer, 1, BUFFER_SIZE, file);
            metrics.bytes_written += bytes;
            fclose(file);
            clock_gettime(CLOCK_MONOTONIC, &end);
            metrics.write_time_us += (end.tv_sec - start.tv_sec) * 1000000 + 
                                   (end.tv_nsec - start.tv_nsec) / 1000;
        }

        // Read operation
        clock_gettime(CLOCK_MONOTONIC, &start);
        file = fopen(TEST_FILE, "r");
        if (file == NULL) {
            metrics.read_errors++;
        } else {
            size_t bytes = fread(buffer, 1, BUFFER_SIZE, file);
            metrics.bytes_read += bytes;
            fclose(file);
            clock_gettime(CLOCK_MONOTONIC, &end);
            metrics.read_time_us += (end.tv_sec - start.tv_sec) * 1000000 + 
                                  (end.tv_nsec - start.tv_nsec) / 1000;
        }

        // Write metrics to file for OpenTelemetry to collect
        write_metrics(&metrics);

        // Sleep before next iteration
        usleep(100000); // 100ms
    }

    return 0;
}
