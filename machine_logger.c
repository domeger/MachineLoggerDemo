#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

int main() {
    FILE *file;
    char buffer[256];
    struct timespec start, end;

    while (1) {
        // Simulate a write operation
        clock_gettime(CLOCK_MONOTONIC, &start);
        file = fopen("/mnt/encrypted/machine_data.txt", "a");
        if (file == NULL) {
            perror("Error opening file for write");
            return 1;
        }
        fprintf(file, "Temperature: %d, Pressure: %d, Timestamp: %ld\n",
                rand() % 100, rand() % 1000, time(NULL));
        fclose(file);
        clock_gettime(CLOCK_MONOTONIC, &end);

        long write_time = (end.tv_sec - start.tv_sec) * 1000000L + (end.tv_nsec - start.tv_nsec) / 1000;
        printf("Write time: %ld µs\n", write_time);

        // Simulate a read operation
        clock_gettime(CLOCK_MONOTONIC, &start);
        file = fopen("/mnt/encrypted/machine_data.txt", "r");
        if (file == NULL) {
            perror("Error opening file for read");
            return 1;
        }
        while (fgets(buffer, sizeof(buffer), file) != NULL) {
            // Simulate processing
        }
        fclose(file);
        clock_gettime(CLOCK_MONOTONIC, &end);

        long read_time = (end.tv_sec - start.tv_sec) * 1000000L + (end.tv_nsec - start.tv_nsec) / 1000;
        printf("Read time: %ld µs\n", read_time);

        // Simulate delay
        usleep(100000); // 100ms
    }

    return 0;
}ls -la