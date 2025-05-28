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

// Package grpcwrapper is a wrapper for the ipamd client Dial interface
package grpcwrapper

import (
	"context"

	google_grpc "google.golang.org/grpc"
)

// GRPC is the ipamd client Dial interface
type GRPC interface {
	Dial(target string, opts ...google_grpc.DialOption) (*google_grpc.ClientConn, error)
	DialContext(ctx context.Context, target string, opts ...google_grpc.DialOption) (*google_grpc.ClientConn, error)
}

type cniGRPC struct{}

// New creates a new cniGRPC
func New() GRPC {
	return &cniGRPC{}
}

func (*cniGRPC) Dial(target string, opts ...google_grpc.DialOption) (*google_grpc.ClientConn, error) {
	return google_grpc.Dial(target, opts...)
}

func (*cniGRPC) DialContext(ctx context.Context, target string, opts ...google_grpc.DialOption) (*google_grpc.ClientConn, error) {
	return google_grpc.DialContext(ctx, target, opts...)
}
