package s3

import (
	"fmt"
	"net/url"
	"strings"
)

func ExtractBucketAndKeyFromURI(s3URI string) (string, string, error) {
	u, err := url.Parse(s3URI)
	if err != nil {
		return "", "", fmt.Errorf("could not parse %s as a URL: %v", s3URI, err)
	}

	if u.Scheme != "s3" {
		return "", "", fmt.Errorf("unsupported s3 URI scheme: %s", u.Scheme)
	}

	bucket := u.Host
	key := strings.TrimPrefix(u.Path, "/")
	return bucket, key, nil
}
