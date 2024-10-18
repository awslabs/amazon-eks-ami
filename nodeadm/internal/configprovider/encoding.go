package configprovider

import (
	"bytes"
	"compress/gzip"
	"encoding/base64"
	"fmt"
	"io"
)

func decodeIfBase64(data []byte) ([]byte, error) {
	e := base64.StdEncoding
	maxDecodedLen := e.DecodedLen(len(data))
	decodedData := make([]byte, maxDecodedLen)
	decodedLen, err := e.Decode(decodedData, data)
	if err != nil {
		return data, nil
	}
	return decodedData[:decodedLen], nil
}

// https://en.wikipedia.org/wiki/Gzip
const gzipMagicNumber = uint16(0x1f8b)

func decompressIfGZIP(data []byte) ([]byte, error) {
	if len(data) < 2 {
		return data, nil
	}
	preamble := uint16(data[0])<<8 | uint16(data[1])
	if preamble == gzipMagicNumber {
		reader, err := gzip.NewReader(bytes.NewReader(data))
		if err != nil {
			return nil, fmt.Errorf("failed to create GZIP reader: %v", err)
		}
		if decompressed, err := io.ReadAll(reader); err != nil {
			return nil, fmt.Errorf("failed to read from GZIP reader: %v", err)
		} else {
			return decompressed, nil
		}
	}
	return data, nil
}
