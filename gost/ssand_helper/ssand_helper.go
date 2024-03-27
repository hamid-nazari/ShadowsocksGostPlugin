package ssand_helper

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
	"strings"
	"syscall"
)

const DEFAULT_SOCKET_PATH = "protect_path"
const GOST_FILES_PATH = "hnzgost_files"
const DEFAULT_DNS_SERVER = "8.8.8.8:53"

const KEY_LEGACY_HOST = "#SS_HOST"
const KEY_LEGACY_PORT = "#SS_PORT"
const KEY_LOCAL_HOST = "#SS_LOCAL_HOST"
const KEY_LOCAL_PORT = "#SS_LOCAL_PORT"
const KEY_REMOTE_HOST = "#SS_REMOTE_HOST"
const KEY_REMOTE_PORT = "#SS_REMOTE_PORT"

type ConfigData struct {
	CmdArgs   [][]string
	DataDir   string
	Files     map[string]string
	DNSServer string
}

var (
	validUsage bool
	VPN        bool
	SocketPath string
	config     ConfigData
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

		err = syscall.Connect(socket, &syscall.SockaddrUnix{Name: SocketPath})
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
			log.Println("Failed to protect fd: ", fd)
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

	SocketPath = PWD + "/" + DEFAULT_SOCKET_PATH

	localHost := os.Getenv("SS_LOCAL_HOST")
	localPort := os.Getenv("SS_LOCAL_PORT")
	remoteHost := os.Getenv("SS_REMOTE_HOST")
	remotePort := os.Getenv("SS_REMOTE_PORT")
	pluginOptions := os.Getenv("SS_PLUGIN_OPTIONS")

	splitted := strings.Split(pluginOptions, ";")
	encoded := ""
	for _, subString := range splitted {
		if strings.HasPrefix(subString, "__android_vpn=") {
			VPN = true
			continue
		}
		if strings.HasPrefix(subString, "CFGBLOB=") {
			encoded = subString[len("CFGBLOB="):]
			continue
		}
	}
	if encoded != "" {
		jsonBytes, err := base64.StdEncoding.WithPadding('_').DecodeString(encoded)
		if err != nil {
			log.Fatal("Base64 decode error: ", err)
		}
		err = json.Unmarshal([]byte(jsonBytes), &config)
		if err != nil {
			log.Fatal("JSON unmarshal error: ", err)
		}
		for _, args := range config.CmdArgs {
			for _, arg := range args {
				if strings.HasPrefix(arg, "\"") && strings.HasSuffix(arg, "\"") {
					arg = arg[1:(len(arg) - 2)]
				}
				arg = strings.ReplaceAll(arg, "#SS_HOST", KEY_REMOTE_HOST)
				arg = strings.ReplaceAll(arg, "#SS_PORT", KEY_REMOTE_PORT)
				arg = strings.ReplaceAll(arg, KEY_REMOTE_HOST, remoteHost)
				arg = strings.ReplaceAll(arg, KEY_REMOTE_PORT, remotePort)
				arg = strings.ReplaceAll(arg, KEY_LOCAL_HOST, localHost)
				arg = strings.ReplaceAll(arg, KEY_LOCAL_PORT, localPort)
				os.Args = append(os.Args, arg)
			}
		}
		dataDir := config.DataDir + "/" + GOST_FILES_PATH
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
		for fileName, fileData := range config.Files {
			err = os.WriteFile(fileName, []byte(fileData), 0600)
			if err != nil {
				log.Fatalf("Can't write GOST file '%s': %v", fileName, err)
			}
		}
	} else {
		config = ConfigData{}

		pluginOptions = strings.ReplaceAll(pluginOptions, "#SS_HOST", remoteHost)
		pluginOptions = strings.ReplaceAll(pluginOptions, "#SS_PORT", remotePort)

		os.Args = append(os.Args, "-L")
		os.Args = append(os.Args, fmt.Sprintf("ss+tcp://none@[%s]:%s", localHost, localPort))
		os.Args = append(os.Args, strings.Split(pluginOptions, ";")...)
	}

	if config.DNSServer == "" {
		config.DNSServer = DEFAULT_DNS_SERVER
	}

	validUsage = localHost != "" && localPort != ""
}

func PostInit() {

	if !validUsage {
		log.Fatal("Can only be used from the ShadowSocks Android Plugin")
	}

	log.Printf("ShadowSocks Android Helper for GOST")
	log.Printf(" - Direct Socket: %s", SocketPath)
	log.Printf(" - DNS: %s", config.DNSServer)
	log.Printf(" - VPN: %v", VPN)

	net.DefaultResolver = &net.Resolver{Dial: func(ctx context.Context, network, address string) (net.Conn, error) {
		dialer := net.Dialer{}
		return dialer.DialContext(ctx, network, config.DNSServer)
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
