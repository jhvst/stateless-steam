# muhos

1. `podman build . --tag muhos`

2. `podman run -v "$PWD:$PWD":z -w "$PWD" muhos`

3. `sudo ./out/result/kexec-boot` (the system will halt)