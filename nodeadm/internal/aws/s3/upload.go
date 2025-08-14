package s3

import (
	"context"
	"fmt"
	"log"
	"os"
	"path"
	"path/filepath"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/s3/manager"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

type Uploader struct {
	uploader *manager.Uploader
}

func NewUploader() (Uploader, error) {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		return Uploader{}, fmt.Errorf("failed to load AWS config for s3 uploader: %v", err)
	}
	s3Client := s3.NewFromConfig(cfg)
	return Uploader{
		uploader: manager.NewUploader(s3Client),
	}, nil
}

func (s Uploader) Upload(ctx context.Context, sourceFilePath string, destinationBucket string, destinationPrefix string) error {
	file, err := os.Open(sourceFilePath)
	if err != nil {
		log.Fatalf("failed to open upload source file: %v", err)
	}
	defer file.Close()

	// Treat the destination key as a prefix by appending the filename to the object path
	renderedDestinationPath := path.Join(destinationPrefix, filepath.Base(sourceFilePath))

	_, err = s.uploader.Upload(ctx, &s3.PutObjectInput{
		Bucket: &destinationBucket,
		Key:    &renderedDestinationPath,
		Body:   file,
	})
	return err
}
