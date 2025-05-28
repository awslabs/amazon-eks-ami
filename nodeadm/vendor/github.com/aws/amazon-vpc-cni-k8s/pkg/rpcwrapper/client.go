// Copyright Amazon.com Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License"). You may
// not use this file except in compliance with the License. A copy of the
// License is located at
//
//     http://aws.amazon.com/apache2.0/
//
// or in the "license" file accompanying this file. This file is distributed
// on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
// express or implied. See the License for the specific language governing
// permissions and limitations under the License.

// Package rpcwrapper is a wrapper for the CNI IPAMD pod connection
package rpcwrapper

import (
	"github.com/aws/amazon-vpc-cni-k8s/rpc"
	grpc "google.golang.org/grpc"
)

// RPC is the wrapper interface for the CNI and network policy agent gRPC backend clients
type RPC interface {
	NewCNIBackendClient(cc *grpc.ClientConn) rpc.CNIBackendClient
	NewNPBackendClient(cc *grpc.ClientConn) rpc.NPBackendClient
}

type cniRPC struct{}

// New returns a new RPC
func New() RPC {
	return &cniRPC{}
}

func (*cniRPC) NewCNIBackendClient(cc *grpc.ClientConn) rpc.CNIBackendClient {
	return rpc.NewCNIBackendClient(cc)
}

func (*cniRPC) NewNPBackendClient(cc *grpc.ClientConn) rpc.NPBackendClient {
	return rpc.NewNPBackendClient(cc)
}
