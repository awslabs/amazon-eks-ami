//go:build wasm

package main

import (
	"fmt"
	"syscall/js"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/configprovider"
)

type jsWrapperFunc = func(this js.Value, args []js.Value) any

func main() {
	for jsFuncName, jsFunc := range map[string]jsWrapperFunc{
		"nodeadmCheck": nodeadmCheckFunc,
	} {
		fmt.Printf("loading %q from Go WASM module\n", jsFuncName)
		js.Global().Set(jsFuncName, js.FuncOf(func(this js.Value, args []js.Value) any {
			defer func() {
				// Since we cannot return errors in proper convention back to
				// javascript through the WebAssembly Goroutine, we'll wrap the
				// panic handler instead and print the information to keep the
				// execution Go-like.
				if r := recover(); r != nil {
					errString := fmt.Sprintf("%s", r)
					fmt.Printf("encountered error: %s\n", errString)
					js.Global().Call("alert", errString)
				}
			}()
			return jsFunc(this, args)
		}))
	}
	// search for a hook in the global namesapace and invoke it. this helps
	// prevent timing issues when attemping to call WASM functions when they are
	// still being loaded.
	if wasmLoadedHook := js.Global().Get("wasmLoadedHook"); wasmLoadedHook.Truthy() {
		wasmLoadedHook.Invoke()
	}
	// block function completion to keep the Go routines loaded in memory
	<-make(chan struct{})
}

var nodeadmCheckFunc = func(this js.Value, args []js.Value) any {
	if len(args) != 1 {
		panic("incorrect number of arguments.")
	}
	document := args[0].String()
	nodeConfig, err := configprovider.ParseMaybeMultipart([]byte(document))
	if err != nil {
		return js.ValueOf(err.Error())
	}
	if err := api.ValidateNodeConfig(nodeConfig); err != nil {
		return js.ValueOf(fmt.Errorf("validating NodeConfig: %w", err).Error())
	}
	return js.ValueOf("Looks Good! 👍")
}
