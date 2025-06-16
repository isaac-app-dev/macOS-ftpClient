import Foundation

class FTPClient {
    private var controlInputStream: InputStream?
    private var controlOutputStream: OutputStream?
    private let ipAddress: String
    private let port: UInt32

    init(ipAddress: String, port: UInt32 = 21) {
        self.ipAddress = ipAddress
        self.port = port
    }

    func connect() {
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?

        CFStreamCreatePairWithSocketToHost(nil, ipAddress as CFString, port, &readStream, &writeStream)

        guard let input = readStream?.takeRetainedValue() as InputStream?,
              let output = writeStream?.takeRetainedValue() as OutputStream? else {
            print("Failed to create control stream")
            return
        }

        controlInputStream = input
        controlOutputStream = output

        controlInputStream?.open()
        controlOutputStream?.open()

        if let response = readResponse() {
            print(response)
        }

        // Set binary mode
        sendCommand("TYPE I")
        if let response = readResponse() {
            print(response)
        }
    }

    func login(username: String, password: String) {
        sendCommand("USER \(sanitizeInput(username))")
        if let response = readResponse() {
            print(response)
        }

        sendCommand("PASS \(sanitizeInput(password))")
        if let response = readResponse() {
            print(response)
        }
    }

    func sendCommand(_ command: String) {
        guard let outputStream = controlOutputStream else { return }
        let commandWithCRLF = command + "\r\n"
        let data = [UInt8](commandWithCRLF.utf8)
        outputStream.write(data, maxLength: data.count)
    }

    func readResponse() -> String? {
        guard let inputStream = controlInputStream else { return nil }
        var buffer = [UInt8](repeating: 0, count: 1024)
        let bytesRead = inputStream.read(&buffer, maxLength: buffer.count)
        if bytesRead > 0 {
            return String(bytes: buffer[0..<bytesRead], encoding: .utf8)
        }
        return nil
    }

    func sanitizeInput(_ input: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.punctuationCharacters).subtracting(.controlCharacters)
        return input.unicodeScalars.filter { allowed.contains($0) }.map(String.init).joined()
    }

    func enterPassiveMode() -> (String, UInt16)? {
        sendCommand("PASV")
        guard let response = readResponse() else { return nil }
        print(response)

        let pattern = #"\((\d+),(\d+),(\d+),(\d+),(\d+),(\d+)\)"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        if let match = regex?.firstMatch(in: response, options: [], range: NSRange(location: 0, length: response.utf16.count)) {
            let parts = (1...6).compactMap { i -> Int? in
                if let range = Range(match.range(at: i), in: response) {
                    return Int(response[range])
                }
                return nil
            }
            if parts.count == 6 {
                let ip = "\(parts[0]).\(parts[1]).\(parts[2]).\(parts[3])"
                let port = UInt16(parts[4]) << 8 | UInt16(parts[5])
                return (ip, port)
            }
        }
        return nil
    }

    func retrieveFile(named fileName: String) {
        let safeFileName = sanitizeInput(fileName)
        guard let (dataIP, dataPort) = enterPassiveMode() else {
            print("Failed to enter passive mode")
            return
        }

        var readStream: Unmanaged<CFReadStream>?
        CFStreamCreatePairWithSocketToHost(nil, dataIP as CFString, UInt32(dataPort), &readStream, nil)

        guard let inputStreamRef = readStream?.takeRetainedValue() as InputStream? else {
            print("Failed to open data stream")
            return
        }

        let dataInputStream = inputStreamRef
        dataInputStream.open()

        sendCommand("RETR \(safeFileName)")
        if let response = readResponse() {
            print(response)
        }

        let filePath = FileManager.default.currentDirectoryPath + "/" + safeFileName
        FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)
        
        guard let fileHandle = FileHandle(forWritingAtPath: filePath) else {
            print("Failed to open local file for writing")
            return
        }
        fileHandle.truncateFile(atOffset: 0)

        var buffer = [UInt8](repeating: 0, count: 1024)
        
        while true {
            let bytesRead = dataInputStream.read(&buffer, maxLength: buffer.count)
            if bytesRead > 0 {
                let data = Data(buffer[0..<bytesRead])
                fileHandle.write(data)
            } else {
                break //EOF or stream closed to ensure we capture the final EOF
            }
        }

        fileHandle.closeFile()
        dataInputStream.close()

        if let response = readResponse() {
            print(response)
        }
    }

    func uploadFile(named fileName: String) {
        let safeFileName = sanitizeInput(fileName)
        guard let (dataIP, dataPort) = enterPassiveMode() else {
            print("Failed to enter passive mode")
            return
        }

        var writeStream: Unmanaged<CFWriteStream>?
        CFStreamCreatePairWithSocketToHost(nil, dataIP as CFString, UInt32(dataPort), nil, &writeStream)

        guard let outputStreamRef = writeStream?.takeRetainedValue() as OutputStream? else {
            print("Failed to open data stream")
            return
        }

        let dataOutputStream = outputStreamRef
        dataOutputStream.open()

        sendCommand("STOR \(safeFileName)")
        if let response = readResponse() {
            print(response)
        }

        guard let fileHandle = FileHandle(forReadingAtPath: safeFileName) else {
            print("Failed to open local file")
            return
        }

        while true {
            let data = fileHandle.readData(ofLength: 1024)
            if data.count == 0 { break }
            _ = data.withUnsafeBytes {
                dataOutputStream.write($0.bindMemory(to: UInt8.self).baseAddress!, maxLength: data.count)
            }
        }

        fileHandle.closeFile()
        dataOutputStream.close()

        if let response = readResponse() {
            print(response)
        }
    }

    func listDirectory() {
        guard let (dataIP, dataPort) = enterPassiveMode() else {
            print("Failed to enter passive mode")
            return
        }

        var readStream: Unmanaged<CFReadStream>?
        CFStreamCreatePairWithSocketToHost(nil, dataIP as CFString, UInt32(dataPort), &readStream, nil)

        guard let inputStreamRef = readStream?.takeRetainedValue() as InputStream? else {
            print("Failed to open data stream")
            return
        }

        let dataInputStream = inputStreamRef
        dataInputStream.open()

        sendCommand("LIST")
        if let response = readResponse() {
            print(response)
        }

        var buffer = [UInt8](repeating: 0, count: 1024)
        while dataInputStream.hasBytesAvailable {
            let bytesRead = dataInputStream.read(&buffer, maxLength: buffer.count)
            if bytesRead > 0 {
                if let output = String(bytes: buffer[0..<bytesRead], encoding: .utf8) {
                    print(output)
                }
            } else {
                break
            }
        }

        dataInputStream.close()
        if let response = readResponse() {
            print(response)
        }
    }

    func changeDirectory(to path: String) {
        let safePath = sanitizeInput(path)
        sendCommand("CWD \(safePath)")
        if let response = readResponse() {
            print(response)
        }
    }

    func printWorkingDirectory() {
        sendCommand("PWD")
        if let response = readResponse() {
            print(response)
        }
    }

    func close() {
        controlInputStream?.close()
        controlOutputStream?.close()
    }
}

// MARK: - Command Line Interface

let arguments = CommandLine.arguments

func parseArguments() -> (String, UInt32) {
    var ip: String?
    var port: UInt32 = 21

    var i = 1
    while i < arguments.count {
        let arg = arguments[i]
        switch arg {
        case "-i":
            if i + 1 < arguments.count {
                ip = arguments[i + 1]
                i += 1
            }
        case "-p":
            if i + 1 < arguments.count, let customPort = UInt32(arguments[i + 1]) {
                port = customPort
                i += 1
            }
        default: break
        }
        i += 1
    }

    guard let ipAddress = ip else {
        print("Usage: ftp -i <ip_address> [-p <port>]")
        exit(1)
    }

    return (ipAddress, port)
}

let (ipAddress, port) = parseArguments()
let ftpClient = FTPClient(ipAddress: ipAddress, port: port)
ftpClient.connect()

print("Enter username:", terminator: " ")
if let username = readLine(), username.count <= 128  {
    print("Enter password:", terminator: " ")
    if let password = readLine(), password.count <= 128 {
        ftpClient.login(username: username, password: password)
    }
}

// Enter interactive mode
while true {
    print("ftp>", terminator: " ")
    guard let commandLine = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !commandLine.isEmpty else { continue }
    guard commandLine.count <= 256 else {
        print("Command too long. Limit input to 256 characters.")
        continue
    }
    let components = commandLine.split(separator: " ", maxSplits: 1).map(String.init)
    let command = components[0].lowercased()
    let argument = components.count > 1 ? components[1] : ""

    switch command {
    case "quit":
        ftpClient.sendCommand("QUIT")
        if let response = ftpClient.readResponse() {
            print(response)
        }
        ftpClient.close()
        exit(0)
    case "get":
        ftpClient.retrieveFile(named: argument)
    case "put":
        ftpClient.uploadFile(named: argument)
    case "dir", "list":
        ftpClient.listDirectory()
    case "cd":
        ftpClient.changeDirectory(to: argument)
    case "pwd":
        ftpClient.printWorkingDirectory()
    default:
        ftpClient.sendCommand(command.uppercased())
        if let response = ftpClient.readResponse() {
            print(response)
        }
    }
}