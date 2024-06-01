//
//  ProcessHandler.swift
//
//
//  Created by Vladimir Solomenchuk on 5/31/24.
//

import Foundation

struct ProcessHandler {
    let executableURL: URL
    let launchPath: String

    struct ProcessCommand {
        typealias Argument = String
        var arguments: [Argument]
    }

    enum ProcessError: Error {
        case failure(code: Int32)
    }

    func run(process: ProcessCommand) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated)
                .async {
                    let task = Process()
                    let output = FileHandle.standardOutput
                    let error = FileHandle.standardError
                    let input = Pipe()

                    task.standardOutput = output
                    task.standardInput = input
                    task.standardError = error
                    task.arguments = process.arguments
                    task.executableURL = executableURL
                    task.launchPath = launchPath
                    // Fix stdin
                    // https://stackoverflow.com/a/74395288
                    let fileHandle = FileHandle(fileDescriptor: STDIN_FILENO)
                    fileHandle.readabilityHandler = { handle in
                        let data = handle.availableData
                        if data.count > 0 {
                            input.fileHandleForWriting.write(data)
                        }
                    }

                    // https://stackoverflow.com/a/45714258
                    let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
                    sigintSrc.setEventHandler {
                        task.terminate()
                    }
                    sigintSrc.resume()

                    do {
                        try task.run()
                        task.waitUntilExit()
                        let returnCode = task.terminationStatus
                        if returnCode == 0 {
                            continuation.resume(returning: ())
                        } else {
                            continuation.resume(throwing: ProcessError.failure(code: returnCode))
                        }
                    } catch {
                        let returnCode = task.terminationStatus
                        continuation.resume(throwing: ProcessError.failure(code: returnCode))
                    }
                }
        }
    }
}
