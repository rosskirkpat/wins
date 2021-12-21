package profilings

import (
	"fmt"
	"github.com/rancher/wins/pkg/defaults"
	"github.com/sirupsen/logrus"
	"golang.org/x/sys/windows"
	"unsafe"

	"strings"
	"syscall"
)


func StackDump(cliContext bool) (bool, error) {
	if cliContext {
		err := callStackDump()
		if err != nil {
			logrus.Errorf("StackDump: failed to call wins stack dump")
			return false, err
		}
		return true, nil
	}
	return false, nil
}


func genCtrlEvent(pid uint32) {
	// send ctrl+break
	err := windows.GenerateConsoleCtrlEvent(1, pid)
	if err != nil {
		return
	}
}

// max amount of process entries that we expect,
// TODO: may need to re-eval this in the future
const processEntrySize = 1024

func findWinsProcess() uint32 {
	h, e := windows.CreateToolhelp32Snapshot(windows.TH32CS_SNAPPROCESS, 0)
	if e != nil {
		panic(e)
	}
	p := windows.ProcessEntry32{Size: processEntrySize}
	for {
		e := windows.Process32Next(h, &p)
		if e != nil { break }
		s := windows.UTF16ToString(p.ExeFile[:])
		if strings.Contains(s, "wins") {
			//pid := int(p.ProcessID)
			pid := p.ProcessID
			logrus.Infof("Found process [%s] with pid [%d]")
			return pid
		} else {
			logrus.Warnf("no process matching [wins] was found")
		}
	}
	return 0
}

//type Signal = syscall.Signal

func callStackDump() error {

	winsProcessId := findWinsProcess()
	// send ctrl+break to the wins process
	//genCtrlEvent(winsProcessId)

	event := fmt.Sprintf("Global\\stackdump-%d", winsProcessId)
	ev, _ := windows.UTF16PtrFromString(event)
	//h, _ := windows.LoadLibrary("kernel32.dll")
	//defer func(handle windows.Handle) {
	//	err := windows.FreeLibrary(handle)
	//	if err != nil {
	//
	//	}
	//}(h)

	//cwd, _ := windows.Getwd()

	// verify that wins is running before trying to send stackdump signal
	if syscall.Signal(syscall.Signal(0)) == 0 {
		logrus.Debugf("Confirmed that process %d is running.", winsProcessId)
	}

	sd, err := windows.SecurityDescriptorFromString(defaults.PermissionBuiltinAdministratorsAndLocalSystem)
	if err != nil {
		return fmt.Errorf("failed to get security descriptor for debug stackdump event %s: %v", event, err)
	}

	var sa windows.SecurityAttributes
	sa.Length = uint32(unsafe.Sizeof(sa))
	sa.InheritHandle = 1
	sa.SecurityDescriptor = sd

	// attempt to open the existing listen event for wins stack dump
	h, _ := windows.OpenEvent(0x1F0003, // EVENT_ALL_ACCESS
		true,
		ev)

	eventErr := windows.SetEvent(h)
	if eventErr != nil {
		return fmt.Errorf("callStackDump: error setting win32 event")
		windows.CloseHandle(h)
	} else {
		err := windows.ResetEvent(h)
		if err != nil {
			return fmt.Errorf("callStackDump: unable to reset signal state for win32 event")
		}
		windows.CloseHandle(h)
	}

	// this should never fail
	// however we want to make sure we don't close an unopened handle
	if h != windows.Handle(0) {
		defer windows.CloseHandle(h)
	}
	return nil
}


