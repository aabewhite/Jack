import Foundation
import Jack

// MARK: FilePod

// fs.mkdir('/tmp/dir')

public class FilePod : JackPod {
    let fm: FileManager

    public init(fm: FileManager = .default) {
        self.fm = fm
    }

    public var metadata: JackPodMetaData {
        JackPodMetaData(homePage: URL(string: "https://www.example.com")!)
    }

    public lazy var pod = jack()

    @Jumped("fileExists") var _fileExists = fileExists
    func fileExists(atPath path: String) -> Bool {
        fm.fileExists(atPath: path)
    }

    @Jumped("createDirectory") var _createDirectory = createDirectory
    func createDirectory(atPath path: String, withIntermediateDirectories dirs: Bool) throws {
        try fm.createDirectory(atPath: path, withIntermediateDirectories: dirs)
    }
}


#if canImport(XCTest)
import XCTest

final class FilePodTests: XCTestCase {
    func testFilePod() async throws {
        let pod = FilePod()

        let jxc = pod.jack().env

        XCTAssertEqual(3, try jxc.eval("1+2").numberValue)
        XCTAssertEqual(true, try jxc.eval("fileExists('/etc/hosts')").booleanValue)

        let tmpname = UUID().uuidString
        let tmpdir = "/tmp/testFilePod/" + tmpname

        XCTAssertEqual(false, try jxc.eval("fileExists('\(tmpdir)')").booleanValue)
        try jxc.eval("createDirectory('\(tmpdir)', true)")
        XCTAssertEqual(true, try jxc.eval("fileExists('\(tmpdir)')").booleanValue)

    }
}
#endif
