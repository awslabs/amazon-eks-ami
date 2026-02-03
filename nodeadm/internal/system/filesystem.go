package system

import (
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type FileSystem interface {
	Glob(pattern string) ([]string, error)
	ReadFile(name string) ([]byte, error)
	ReadDir(name string) ([]fs.DirEntry, error)
	Stat(name string) (fs.FileInfo, error)
}

type RealFileSystem struct{}

func (RealFileSystem) Glob(pattern string) ([]string, error) {
	return filepath.Glob(pattern)
}

func (RealFileSystem) ReadFile(name string) ([]byte, error) {
	// This has a slight issue since gosec will not flag lines that call RealFileSystem.ReadFile.
	// #nosec G304 intended usage.
	return os.ReadFile(name)
}

func (RealFileSystem) ReadDir(name string) ([]fs.DirEntry, error) {
	return os.ReadDir(name)
}

func (RealFileSystem) Stat(name string) (fs.FileInfo, error) {
	return os.Stat(name)
}

const EmptyDirectoryMarker = "[empty directory]"

type FakeFileSystem struct {
	Files map[string]string
}

func (f FakeFileSystem) allPaths() map[string]bool {
	paths := make(map[string]bool)
	for path := range f.Files {
		paths[path] = true
		for dir := filepath.Dir(path); dir != "/" && dir != "."; dir = filepath.Dir(dir) {
			paths[dir] = true
		}
	}
	return paths
}

func (f FakeFileSystem) Glob(pattern string) ([]string, error) {
	var matches []string
	for path := range f.allPaths() {
		matched, err := filepath.Match(pattern, path)
		if err != nil {
			return nil, err
		}
		if matched {
			matches = append(matches, path)
		}
	}
	return matches, nil
}

func (f FakeFileSystem) ReadFile(name string) ([]byte, error) {
	content, ok := f.Files[name]
	if !ok {
		return nil, os.ErrNotExist
	}
	if content == EmptyDirectoryMarker {
		return nil, &os.PathError{Op: "read", Path: name, Err: os.ErrInvalid}
	}
	return []byte(content), nil
}

func (f FakeFileSystem) ReadDir(name string) ([]fs.DirEntry, error) {
	name = strings.TrimSuffix(name, "/")
	if content, ok := f.Files[name]; ok && content != EmptyDirectoryMarker {
		return nil, &os.PathError{Op: "readdir", Path: name, Err: os.ErrInvalid}
	}

	var entries []fs.DirEntry
	seen := make(map[string]bool)
	prefix := name + "/"

	for path := range f.Files {
		if !strings.HasPrefix(path, prefix) {
			continue
		}
		rest := strings.TrimPrefix(path, prefix)
		parts := strings.SplitN(rest, "/", 2)
		entryName := parts[0]
		if seen[entryName] {
			continue
		}
		seen[entryName] = true

		entryPath := name + "/" + entryName
		entries = append(entries, &fakeEntry{name: entryName, isDir: f.isDir(entryPath)})
	}

	if len(entries) == 0 {
		if _, ok := f.Files[name]; !ok {
			return nil, os.ErrNotExist
		}
	}
	return entries, nil
}

func (f FakeFileSystem) isDir(name string) bool {
	if content, ok := f.Files[name]; ok && content == EmptyDirectoryMarker {
		return true
	}
	prefix := name + "/"
	for path := range f.Files {
		if strings.HasPrefix(path, prefix) {
			return true
		}
	}
	return false
}

func (f FakeFileSystem) Stat(name string) (fs.FileInfo, error) {
	name = strings.TrimSuffix(name, "/")
	if content, ok := f.Files[name]; ok {
		return &fakeFileInfo{name: filepath.Base(name), isDir: content == EmptyDirectoryMarker, size: int64(len(content))}, nil
	}
	if f.isDir(name) {
		return &fakeFileInfo{name: filepath.Base(name), isDir: true}, nil
	}
	return nil, os.ErrNotExist
}

type fakeEntry struct {
	name  string
	isDir bool
}

func (e *fakeEntry) Name() string { return e.name }
func (e *fakeEntry) IsDir() bool  { return e.isDir }
func (e *fakeEntry) Type() fs.FileMode {
	if e.isDir {
		return fs.ModeDir
	}
	return 0
}
func (e *fakeEntry) Info() (fs.FileInfo, error) {
	return &fakeFileInfo{name: e.name, isDir: e.isDir}, nil
}

type fakeFileInfo struct {
	name  string
	isDir bool
	size  int64
}

func (fi *fakeFileInfo) Name() string { return fi.name }
func (fi *fakeFileInfo) Size() int64  { return fi.size }
func (fi *fakeFileInfo) Mode() fs.FileMode {
	if fi.isDir {
		return fs.ModeDir | 0755
	}
	return 0644
}
func (fi *fakeFileInfo) ModTime() time.Time { return time.Time{} }
func (fi *fakeFileInfo) IsDir() bool        { return fi.isDir }
func (fi *fakeFileInfo) Sys() any           { return nil }
