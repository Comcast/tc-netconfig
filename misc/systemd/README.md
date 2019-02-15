# systemd files

These files can be used to run `tc-netconfig` as a systemd service.

`netconfig.service`  
- install into /usr/lib/systemd/system/

`netconfig-wrapper.sh`  
- wrapper script, used by the service
- determines if server is in an unconfigured network state, and executes `tc-netconfig` if needed
- if a new config is installed, restarts networking
