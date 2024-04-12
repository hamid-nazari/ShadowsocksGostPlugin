package gost_helper

/*
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/uio.h>

#define ANCIL_FD_BUFFER(n) \
    struct { \
        struct cmsghdr h; \
        int fd[n]; \
    }

int
ancil_send_fds_with_buffer(int sock, const int *fds, unsigned n_fds, void *buffer)
{
    struct msghdr msghdr;
    char nothing = '!';
    struct iovec nothing_ptr;
    struct cmsghdr *cmsg;
    int i;

    nothing_ptr.iov_base = &nothing;
    nothing_ptr.iov_len = 1;
    msghdr.msg_name = NULL;
    msghdr.msg_namelen = 0;
    msghdr.msg_iov = &nothing_ptr;
    msghdr.msg_iovlen = 1;
    msghdr.msg_flags = 0;
    msghdr.msg_control = buffer;
    msghdr.msg_controllen = sizeof(struct cmsghdr) + sizeof(int) * n_fds;
    cmsg = CMSG_FIRSTHDR(&msghdr);
    cmsg->cmsg_len = msghdr.msg_controllen;
    cmsg->cmsg_level = SOL_SOCKET;
    cmsg->cmsg_type = SCM_RIGHTS;
    for(i = 0; i < n_fds; i++)
        ((int *)CMSG_DATA(cmsg))[i] = fds[i];
    return(sendmsg(sock, &msghdr, 0) >= 0 ? 0 : -1);
}

int
ancil_send_fd(int sock, int fd)
{
    ANCIL_FD_BUFFER(1) buffer;

    return(ancil_send_fds_with_buffer(sock, &fd, 1, &buffer));
}

void
set_timeout(int sock)
{
    struct timeval tv;
    tv.tv_sec  = 3;
    tv.tv_usec = 0;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (char *)&tv, sizeof(struct timeval));
    setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, (char *)&tv, sizeof(struct timeval));
}

*/
import "C"

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"os"
	"runtime"
	"strings"
	"syscall"
)

const DIRECT_SOCKET_PATH = "protect_path"
const GOST_FILES_PATH = "gost_files"
const DEFAULT_DNS_SERVER = "8.8.8.8:53"

const VAR_LOCAL_HOST = "SS_LOCAL_HOST"
const VAR_LOCAL_PORT = "SS_LOCAL_PORT"
const VAR_REMOTE_HOST = "SS_REMOTE_HOST"
const VAR_REMOTE_PORT = "SS_REMOTE_PORT"
const VAR_PLUGIN_OPTIONS = "SS_PLUGIN_OPTIONS"

const PO_ENCODED = "encoded="
const PO_LEGACY_ENCODED = "CFGBLOB="
const PO_VPN_MODE = "__android_vpn="

const FILE_NAME_CONFIG = "config.yaml"

const KEY_LEGACY_HOST = "#SS_HOST"
const KEY_LEGACY_PORT = "#SS_PORT"
const KEY_LOCAL_HOST = "${local.host}"
const KEY_LOCAL_PORT = "${local.port}"
const KEY_REMOTE_HOST = "${remote.host}"
const KEY_REMOTE_PORT = "${remote.port}"

const CONFIG_LOG_ENTRY = "log:"
const CONFIG_NO_LOG = "\nlog:\n   level: info\n   format: json\n   output: none\n"

type ConfigData struct {
	CmdArgs   [][]string
	DataDir   string
	Files     map[string]string
	DNSServer string
}

var (
	validUsage bool
	VPN        bool
	socketPath string
	configData ConfigData
	Version    string
	localHost  string
	localPort  string
	remoteHost string
	remotePort string
)

func ControlOnConnSetup(network string, address string, connection syscall.RawConn) error {
	_callback := func(s uintptr) {
		fd := int(s)
		socket, err := syscall.Socket(syscall.AF_UNIX, syscall.SOCK_STREAM, 0)
		if err != nil {
			log.Println(err)
			return
		}

		defer syscall.Close(socket)

		C.set_timeout(C.int(socket))

		err = syscall.Connect(socket, &syscall.SockaddrUnix{Name: socketPath})
		if err != nil {
			log.Println(err)
			return
		}

		C.ancil_send_fd(C.int(socket), C.int(fd))

		dummy := []byte{1}
		n, err := syscall.Read(socket, dummy)
		if err != nil {
			log.Println(err)
			return
		}
		if n != 1 {
			log.Println("Failed to protect file descriptor: ", fd)
			return
		}
	}

	if err := connection.Control(_callback); err != nil {
		return err
	}

	return nil
}

func PreInit() {

	PWD, err := os.Getwd()

	if err != nil {
		log.Fatal("Can't obtain current working directory: ", err)
	}

	socketPath = PWD + "/" + DIRECT_SOCKET_PATH

	localHost = os.Getenv(VAR_LOCAL_HOST)
	localPort = os.Getenv(VAR_LOCAL_PORT)
	remoteHost = os.Getenv(VAR_REMOTE_HOST)
	remotePort = os.Getenv(VAR_REMOTE_PORT)
	pluginOptions := os.Getenv(VAR_PLUGIN_OPTIONS)

	var hasLogConfig bool
	var appendConfigFile bool
	var dataDir string

	splitted := strings.Split(pluginOptions, ";")
	encoded := ""
	for _, subString := range splitted {
		if strings.HasPrefix(subString, PO_VPN_MODE) {
			VPN = true
			pluginOptions = strings.ReplaceAll(pluginOptions, PO_VPN_MODE+";", "")
			continue
		}
		if strings.HasPrefix(subString, PO_ENCODED) {
			encoded = subString[len(PO_ENCODED):]
			continue
		}
		if strings.HasPrefix(subString, PO_LEGACY_ENCODED) {
			encoded = subString[len(PO_LEGACY_ENCODED):]
			continue
		}
	}
	if encoded != "" {
		jsonBytes, err := base64.RawStdEncoding.DecodeString(encoded)
		if err != nil {
			log.Fatal("Base64 decoding error: ", err)
		}
		err = json.Unmarshal([]byte(jsonBytes), &configData)
		if err != nil {
			log.Fatal("JSON unmarshal error: ", err)
		}
		for _, args := range configData.CmdArgs {
			for _, arg := range args {
				if strings.HasPrefix(arg, "\"") && strings.HasSuffix(arg, "\"") {
					arg = arg[1:(len(arg) - 2)]
				}
				arg = replaceLegacyConfigKeys(arg)
				arg = replaceConfigKeys(arg)
				os.Args = append(os.Args, arg)
			}
		}
		dataDir = configData.DataDir + "/" + GOST_FILES_PATH
		os.MkdirAll(dataDir, 0700)
		err = os.Chdir(dataDir)
		if err != nil {
			log.Fatalf("Can't change directory to '%s': %v", dataDir, err)
		}
		existing, err := os.ReadDir(".")
		if err != nil {
			log.Fatalf("Can't fetch directory '%s' contents: %v", dataDir, err)
		}
		for _, dirEntry := range existing {
			err = os.Remove(dirEntry.Name())
			if err != nil {
				fmt.Fprintf(os.Stderr, "Can't remove an existing file '%s': %v", dirEntry.Name(), err)
			}
		}
		for fileName, fileData := range configData.Files {
			if strings.EqualFold(fileName, FILE_NAME_CONFIG) && strings.Contains(fileData, CONFIG_LOG_ENTRY) {
				hasLogConfig = true
				appendConfigFile = true
			}
			err = os.WriteFile(fileName, []byte(fileData), 0600)
			if err != nil {
				log.Fatalf("Can't write GOST file '%s': %v", fileName, err)
			}
		}
	} else {
		configData = ConfigData{}
		dataDir = PWD

		pluginOptions = replaceLegacyConfigKeys(pluginOptions)
		pluginOptions = replaceConfigKeys(pluginOptions)

		os.Args = append(os.Args, "-L")
		os.Args = append(os.Args, fmt.Sprintf("ss+tcp://none@%s:%s", localHost, localPort))
		os.Args = append(os.Args, strings.Split(pluginOptions, " ")...)
	}

	configFilePath := dataDir + "/" + FILE_NAME_CONFIG

	// This is to make sure config.yaml is always included (even if it is empty) and logging is either configured by user or is off
	if !hasLogConfig {
		openFlags := os.O_CREATE | os.O_WRONLY
		if appendConfigFile {
			openFlags |= os.O_APPEND
		}

		fConfig, err := os.OpenFile(configFilePath, openFlags, 0644)
		if err == nil {
			fConfig.WriteString(CONFIG_NO_LOG)
			fConfig.Close()
		}
	}

	os.Args = append(os.Args, "-C")
	os.Args = append(os.Args, configFilePath)

	if configData.DNSServer == "" {
		configData.DNSServer = DEFAULT_DNS_SERVER
	}

	validUsage = localHost != "" && localPort != ""

}

func PostInit() {

	if !validUsage {
		log.Fatal("Can only be used from the ShadowSocks Android Plugin")
	}

	log.Printf("ShadowSocks Android Helper for GOST")
	log.Printf(" - GOST: v%s (%s %s/%s)", Version, runtime.Version(), runtime.GOOS, runtime.GOARCH)
	log.Printf(" - Direct Socket: %s", socketPath)
	log.Printf(" - DNS: %s", configData.DNSServer)
	log.Printf(" - VPN: %v", VPN)
	log.Printf(" - Args: %v", os.Args)

	net.DefaultResolver = &net.Resolver{Dial: func(ctx context.Context, network, address string) (net.Conn, error) {
		dialer := net.Dialer{}
		return dialer.DialContext(ctx, network, configData.DNSServer)
	}, PreferGo: true}

	if VPN {
		net.ListenUDPListenConfigHook = func(config *net.ListenConfig) {
			config.Control = ControlOnConnSetup
		}
		net.DialContextDialerHook = func(dialer *net.Dialer) {
			dialer.Control = ControlOnConnSetup
		}
	}
}

func replaceLegacyConfigKeys(configKey string) string {
	if !strings.Contains(configKey, "#") {
		return configKey
	}

	configKey = strings.ReplaceAll(configKey, KEY_LEGACY_HOST, KEY_REMOTE_HOST)
	configKey = strings.ReplaceAll(configKey, KEY_LEGACY_PORT, KEY_REMOTE_PORT)
	configKey = strings.ReplaceAll(configKey, "#"+VAR_LOCAL_HOST, KEY_LOCAL_HOST)
	configKey = strings.ReplaceAll(configKey, "#"+VAR_LOCAL_PORT, KEY_LOCAL_PORT)
	configKey = strings.ReplaceAll(configKey, "#"+VAR_REMOTE_HOST, KEY_REMOTE_HOST)
	configKey = strings.ReplaceAll(configKey, "#"+VAR_REMOTE_PORT, KEY_REMOTE_PORT)

	return configKey
}

func replaceConfigKeys(configKey string) string {
	if !strings.Contains(configKey, "${") {
		return configKey
	}

	configKey = strings.ReplaceAll(configKey, KEY_REMOTE_HOST, remoteHost)
	configKey = strings.ReplaceAll(configKey, KEY_REMOTE_PORT, remotePort)
	configKey = strings.ReplaceAll(configKey, KEY_LOCAL_HOST, localHost)
	configKey = strings.ReplaceAll(configKey, KEY_LOCAL_PORT, localPort)

	return configKey
}
