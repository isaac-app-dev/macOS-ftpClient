# Swift FTP Client for macOS

A native FTP client written in Swift, designed for command-line use on macOS. This tool is optimized for investigative and research purposes using fake or disposable credentials.

---

## ✨ Features

- Connects to standard or custom FTP servers (default port: 21)
- Supports FTP raw commands under the hood (RETR, LIST, PASV, etc.)
- Human-friendly command aliases (`get`, `put`, `dir`, `cd`, etc.)
- Handles passive mode data connections (PASV)
- Maintains session until the user types `quit` to end session
- Input sanitization and length restrictions for improved security and usability
- Works entirely via command line — no third-party libraries required

---

## 🛠️ Build Instructions

You can build the FTP client directly using the Swift compiler.

### Step 1: Clone the Repository

```zsh

mkdir ftp

```

```zsh

cd ftp

```

```zsh

git clone https://github.com/isaac-app-dev/macOS-ftpClient.git .

```

### Step 2: Compile the Client

```zsh

mkdir bin

```

```zsh

swiftc src/main.swift -o bin/ftp

```

This will generate an executable named 'ftp' in the bin folder of this git repository. You may name the executable to anything you want that fits your usage needs.

### Step 3: Create a Link

To avoid adding this repo to your PATH, it is best practice to create a symlink for the ftp executable in your /usr/local/bin directory. You will need elevated privileges as you are updating a system folder.

```zsh
# Ensure to use the full/absolute path to the ftp executable
sudo ln -s '<full path to ftp executable>' /usr/local/bin/

```

---

## 🚀 Usage

-i, IP Address, is the only required option for this client. If FTP is running on a port other than the default, 21, e.g. through port forwarding, you may override the default port number with the -p, port flag.

```zsh

ftp -i 10.10.10.10

```

```zsh

ftp -i 127.0.0.1 -p 1337

```

---

## 💻 FTP Prompt Commands

Once connected, you’ll enter an interactive ftp> prompt

Command List:

| Command | Action |
|:-----------|:------------:|
| get download.txt    |   Download a File    |
| put upload.txt    |   Upload a File    |
| dir   |   List directory contents   |
| cd /new/dir/path   |   Change Working Directory   |
| pwd   |   Print Working Directory    |
| quit   |   Exit Session and Close Client   |


### Examples

```zsh
ftp> get sample.txt
ftp> put upload.txt
ftp> cd testfolder
ftp> dir
ftp> quit
```


---

## ⚠️ Security Note

This tool uses unencrypted FTP. Credentials and data are transmitted in plaintext.Do not use with sensitive information.

---

## 📄 License

MIT License

---

## 👤 Author

Developed by Isaac Zapata

[Github Profile](https://github.com/isaac-app-dev)

---