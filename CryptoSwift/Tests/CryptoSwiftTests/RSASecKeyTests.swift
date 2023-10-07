//
//  CryptoSwift
//
//  Copyright (C) 2014-2021 Marcin Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

#if canImport(Security)

  import Security
  import XCTest
  @testable import CryptoSwift

  final class RSASecKeyTests: XCTestCase {

    // MARK: SecKey <-> RSA Interoperability

    /// From CryptoSwift RSA -> External Representation -> SecKey
    ///
    /// This test enforces that
    /// 1) We can export the raw external representation of a CryptoSwift RSA Public Key
    /// 2) And that we can import / create an RSA SecKey from that raw external representation
    /// 3) Proves interoperability between Apple's `Security` Framework and `CryptoSwift`
    func testRSAExternalRepresentationPublic() throws {

      // Generate a CryptoSwift RSA Key
      let rsaCryptoSwift = try RSA(keySize: 1024)

      // Get the key's rawExternalRepresentation
      let rsaCryptoSwiftRawRep = try rsaCryptoSwift.publicKeyDER()

      // We should be able to instantiate an RSA SecKey from this data
      let attributes: [String: Any] = [
        kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
        kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
        kSecAttrKeySizeInBits as String: 1024,
        kSecAttrIsPermanent as String: false
      ]
      var error: Unmanaged<CFError>?
      guard let rsaSecKey = SecKeyCreateWithData(Data(rsaCryptoSwiftRawRep) as CFData, attributes as CFDictionary, &error) else {
        XCTFail("Error constructing SecKey from raw key data: \(error.debugDescription)")
        return
      }

      // Get the SecKey's external representation
      var externalRepError: Unmanaged<CFError>?
      guard let rsaSecKeyRawRep = SecKeyCopyExternalRepresentation(rsaSecKey, &externalRepError) as? Data else {
        XCTFail("Failed to copy external representation for RSA SecKey")
        return
      }

      // Ensure both the CryptoSwift Ext Rep and the SecKey Ext Rep match
      XCTAssertEqual(rsaSecKeyRawRep, Data(rsaCryptoSwiftRawRep))
      XCTAssertEqual(rsaSecKeyRawRep, try rsaCryptoSwift.publicKeyExternalRepresentation())
    }

    /// From CryptoSwift RSA -> External Representation -> SecKey
    ///
    /// This test enforces that
    /// 1) We can export the raw external representation of a CryptoSwift RSA Private Key
    /// 2) And that we can import / create an RSA SecKey from that raw external representation
    /// 3) Proves interoperability between Apple's `Security` Framework and `CryptoSwift`
    func testRSAExternalRepresentationPrivate() throws {

      // Generate a CryptoSwift RSA Key
      let rsaCryptoSwift = try RSA(keySize: 1024)

      // Get the key's rawExternalRepresentation
      let rsaCryptoSwiftRawRep = try rsaCryptoSwift.privateKeyDER()

      // We should be able to instantiate an RSA SecKey from this data
      let attributes: [String: Any] = [
        kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
        kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
        kSecAttrKeySizeInBits as String: 1024,
        kSecAttrIsPermanent as String: false
      ]
      var error: Unmanaged<CFError>?
      guard let rsaSecKey = SecKeyCreateWithData(Data(rsaCryptoSwiftRawRep) as CFData, attributes as CFDictionary, &error) else {
        XCTFail("Error constructing SecKey from raw key data: \(error.debugDescription)")
        return
      }

      // Get the SecKey's external representation
      var externalRepError: Unmanaged<CFError>?
      guard let rsaSecKeyRawRep = SecKeyCopyExternalRepresentation(rsaSecKey, &externalRepError) as? Data else {
        XCTFail("Failed to copy external representation for RSA SecKey")
        return
      }

      // Ensure both the CryptoSwift Ext Rep and the SecKey Ext Rep match
      XCTAssertEqual(rsaSecKeyRawRep, Data(rsaCryptoSwiftRawRep))
      XCTAssertEqual(rsaSecKeyRawRep, try rsaCryptoSwift.externalRepresentation())
    }

    /// From SecKey -> External Representation -> CryptoSwift RSA
    ///
    /// This test enforces that
    /// 1) Given the raw external representation of a Public RSA SecKey, we can import that same key into CryptoSwift
    /// 2) When we export the raw external representation of the RSA Key we get the exact same data
    /// 3) Proves interoperability between Apple's `Security` Framework and `CryptoSwift`
    func testSecKeyExternalRepresentationPublic() throws {
      // Generate a SecKey RSA Key
      let parameters: [CFString: Any] = [
        kSecAttrKeyType: kSecAttrKeyTypeRSA,
        kSecAttrKeySizeInBits: 1024
      ]

      var error: Unmanaged<CFError>?

      // Generate the RSA SecKey
      guard let rsaSecKey = SecKeyCreateRandomKey(parameters as CFDictionary, &error) else {
        XCTFail("Key Generation Error: \(error.debugDescription)")
        return
      }

      // Extract the public key from the private RSA SecKey
      guard let rsaSecKeyPublic = SecKeyCopyPublicKey(rsaSecKey) else {
        XCTFail("Public Key Extraction Error")
        return
      }

      // Let's grab the external representation of the public key
      var externalRepError: Unmanaged<CFError>?
      guard let rsaSecKeyRawRep = SecKeyCopyExternalRepresentation(rsaSecKeyPublic, &externalRepError) as? Data else {
        XCTFail("Failed to copy external representation for RSA SecKey")
        return
      }

      // Ensure we can import the private RSA key into CryptoSwift
      let rsaCryptoSwift = try RSA(rawRepresentation: rsaSecKeyRawRep)

      XCTAssertNil(rsaCryptoSwift.d)
      XCTAssertEqual(rsaSecKeyRawRep, try rsaCryptoSwift.externalRepresentation())
    }

    /// From SecKey -> External Representation -> CryptoSwift RSA
    ///
    /// This test enforces that
    /// 1) Given the raw external representation of a Private RSA SecKey, we can import that same key into CryptoSwift
    /// 2) When we export the raw external representation of the RSA Key we get the exact same data
    /// 3) Proves interoperability between Apple's `Security` Framework and `CryptoSwift`
    func testSecKeyExternalRepresentationPrivate() throws {
      // Generate a SecKey RSA Key
      let parameters: [CFString: Any] = [
        kSecAttrKeyType: kSecAttrKeyTypeRSA,
        kSecAttrKeySizeInBits: 1024
      ]

      var error: Unmanaged<CFError>?

      // Generate the RSA SecKey
      guard let rsaSecKey = SecKeyCreateRandomKey(parameters as CFDictionary, &error) else {
        XCTFail("Key Generation Error: \(error.debugDescription)")
        return
      }

      // Let's grab the external representation
      var externalRepError: Unmanaged<CFError>?
      guard let rsaSecKeyRawRep = SecKeyCopyExternalRepresentation(rsaSecKey, &externalRepError) as? Data else {
        XCTFail("Failed to copy external representation for RSA SecKey")
        return
      }

      // Ensure we can import the private RSA key into CryptoSwift
      let rsaCryptoSwift = try RSA(rawRepresentation: rsaSecKeyRawRep)

      XCTAssertNotNil(rsaCryptoSwift.d)
      XCTAssertEqual(rsaSecKeyRawRep, try rsaCryptoSwift.externalRepresentation())
    }

    /// This test generates X RSA keys and tests them between `Security` and `CryptoSwift` for interoperability
    ///
    /// For each key generated, this test enforces that
    /// 1) We can import the raw external representation (generated by the `Security` framework) of the RSA Key into `CryptoSwift`
    /// 2) When signing messages using a deterministic variant, we get the same output from both `Security` and `CryptoSwift`
    /// 3) We can verify a signature generated from `CryptoSwift` with `Security` and vice versa
    /// 4) We can encrypt and decrypt a message generated from `CryptoSwift` with `Security` and vice versa
    func testRSASecKeys() throws {

      let tests = 3
      let messageToSign: String = "RSA Keys!"

      for _ in 0..<tests {

        // Generate a SecKey RSA Key
        let parameters: [CFString: Any] = [
          kSecAttrKeyType: kSecAttrKeyTypeRSA,
          kSecAttrKeySizeInBits: 1024
        ]

        var error: Unmanaged<CFError>?

        // Generate the RSA SecKey
        guard let rsaSecKey = SecKeyCreateRandomKey(parameters as CFDictionary, &error) else {
          XCTFail("Key Generation Error: \(error.debugDescription)")
          break
        }

        // Let's grab the external representation
        var externalRepError: Unmanaged<CFError>?
        guard let rsaSecKeyRawRep = SecKeyCopyExternalRepresentation(rsaSecKey, &externalRepError) as? Data else {
          XCTFail("Failed to copy external representation for RSA SecKey")
          break
        }

        // Ensure we can import the private RSA key into CryptoSwift
        let rsaCryptoSwift = try RSA(rawRepresentation: rsaSecKeyRawRep)

        // Sign the message with both keys and ensure they're the same (the pkcs1v15 signature variant is deterministic)
        let csSignature = try rsaCryptoSwift.sign(messageToSign.bytes, variant: .message_pkcs1v15_SHA256)

        let skSignature = try secKeySign(messageToSign.bytes, variant: .rsaSignatureMessagePKCS1v15SHA256, withKey: rsaSecKey)

        XCTAssertEqual(csSignature, skSignature.bytes, "Signatures don't match!")

        // Ensure we can verify each signature using the opposite library
        XCTAssertTrue(try rsaCryptoSwift.verify(signature: skSignature.bytes, for: messageToSign.bytes, variant: .message_pkcs1v15_SHA256))
        XCTAssertTrue(try self.secKeyVerify(csSignature, forBytes: messageToSign.bytes, usingVariant: .rsaSignatureMessagePKCS1v15SHA256, withKey: rsaSecKey))

        // Encrypt with SecKey
        let skEncryption = try secKeyEncrypt(messageToSign.bytes, usingVariant: .rsaEncryptionRaw, withKey: rsaSecKey)
        // Decrypt with CryptoSwift Key
        XCTAssertEqual(try rsaCryptoSwift.decrypt(skEncryption.bytes, variant: .raw), messageToSign.bytes, "CryptoSwift Decryption of SecKey Encryption Failed")

        // Encrypt with CryptoSwift
        let csEncryption = try rsaCryptoSwift.encrypt(messageToSign.bytes, variant: .raw)
        // Decrypt with SecKey
        XCTAssertEqual(try self.secKeyDecrypt(csEncryption, usingVariant: .rsaEncryptionRaw, withKey: rsaSecKey).bytes, messageToSign.bytes, "SecKey Decryption of CryptoSwift Encryption Failed")

        XCTAssertEqual(csEncryption, skEncryption.bytes, "Encrypted Data Does Not Match")

        // Encrypt with SecKey
        let skEncryption2 = try secKeyEncrypt(messageToSign.bytes, usingVariant: .rsaEncryptionPKCS1, withKey: rsaSecKey)
        // Decrypt with CryptoSwift Key
        XCTAssertEqual(try rsaCryptoSwift.decrypt(skEncryption2.bytes, variant: .pksc1v15), messageToSign.bytes, "CryptoSwift Decryption of SecKey Encryption Failed")

        // Encrypt with CryptoSwift
        let csEncryption2 = try rsaCryptoSwift.encrypt(messageToSign.bytes, variant: .pksc1v15)
        // Decrypt with SecKey
        XCTAssertEqual(try self.secKeyDecrypt(csEncryption2, usingVariant: .rsaEncryptionPKCS1, withKey: rsaSecKey).bytes, messageToSign.bytes, "SecKey Decryption of CryptoSwift Encryption Failed")
      }
    }

    private func secKeySign(_ bytes: Array<UInt8>, variant: SecKeyAlgorithm, withKey key: SecKey) throws -> Data {
      var error: Unmanaged<CFError>?

      // Sign the data
      guard let signature = SecKeyCreateSignature(
        key,
        variant,
        Data(bytes) as CFData,
        &error
      ) as Data?
      else { throw NSError(domain: "Failed to sign bytes: \(bytes)", code: 0) }

      return signature
    }

    private func secKeyVerify(_ signature: Array<UInt8>, forBytes bytes: Array<UInt8>, usingVariant variant: SecKeyAlgorithm, withKey key: SecKey) throws -> Bool {
      let pubKey = SecKeyCopyPublicKey(key)!

      var error: Unmanaged<CFError>?

      // Perform the signature verification
      let result = SecKeyVerifySignature(
        pubKey,
        variant,
        Data(bytes) as CFData,
        Data(signature) as CFData,
        &error
      )

      // Throw the error if we encountered one...
      if let error = error { throw error.takeRetainedValue() as Error }

      // return the result of the verification
      return result
    }

    private func secKeyEncrypt(_ bytes: Array<UInt8>, usingVariant variant: SecKeyAlgorithm, withKey key: SecKey) throws -> Data {
      let pubKey = SecKeyCopyPublicKey(key)!

      var error: Unmanaged<CFError>?

      guard let encryptedData = SecKeyCreateEncryptedData(pubKey, variant, Data(bytes) as CFData, &error) else {
        throw NSError(domain: "Error Encrypting Data: \(error.debugDescription)", code: 0, userInfo: nil)
      }

      // Throw the error if we encountered one...
      if let error = error { throw error.takeRetainedValue() as Error }

      // return the result of the encryption
      return encryptedData as Data
    }

    private func secKeyDecrypt(_ bytes: Array<UInt8>, usingVariant variant: SecKeyAlgorithm, withKey key: SecKey) throws -> Data {
      var error: Unmanaged<CFError>?
      guard let decryptedData = SecKeyCreateDecryptedData(key, variant, Data(bytes) as CFData, &error) else {
        throw NSError(domain: "Error Decrypting Data: \(error.debugDescription)", code: 0, userInfo: nil)
      }
      return (decryptedData as Data).drop { $0 == 0x00 }
    }
  }

  extension RSASecKeyTests {
    static func allTests() -> [(String, (RSASecKeyTests) -> () throws -> Void)] {
      let tests = [
        ("testRSAExternalRepresentationPublic", testRSAExternalRepresentationPublic),
        ("testRSAExternalRepresentationPrivate", testRSAExternalRepresentationPrivate),
        ("testSecKeyExternalRepresentationPublic", testSecKeyExternalRepresentationPublic),
        ("testSecKeyExternalRepresentationPrivate", testSecKeyExternalRepresentationPrivate),
        ("testRSASecKeys", testRSASecKeys)
      ]

      return tests
    }
  }

  // - MARK: Test Fixture Generation Code
  extension RSASecKeyTests {

    /// This 'Test' generates an RSA Key and uses that key to sign and encrypt a series of messages that we can test against.
    ///
    /// It prints a `Fixture` object that can be copy and pasted / used in other tests.
    func testCreateTestFixture() throws {

      let keySize = 1024
      let messages = [
        "",
        "👋",
        "RSA Keys",
        "CryptoSwift RSA Keys!",
        "CryptoSwift RSA Keys are really cool! They support encrypting / decrypting messages, signing and verifying signed messages, and importing and exporting encrypted keys for use between sessions 🔐"
      ]
      print(messages.map { $0.bytes.count })

      /// Generate a SecKey RSA Key
      let parameters: [CFString: Any] = [
        kSecAttrKeyType: kSecAttrKeyTypeRSA,
        kSecAttrKeySizeInBits: keySize
      ]

      var error: Unmanaged<CFError>?

      // Generate the RSA SecKey
      guard let rsaSecKey = SecKeyCreateRandomKey(parameters as CFDictionary, &error) else {
        XCTFail("Key Generation Error: \(error.debugDescription)")
        return
      }

      // Extract the public key from the private RSA SecKey
      guard let rsaSecKeyPublic = SecKeyCopyPublicKey(rsaSecKey) else {
        XCTFail("Public Key Extraction Error")
        return
      }

      /// Let's grab the external representation of the public key
      var publicExternalRepError: Unmanaged<CFError>?
      guard let publicRSASecKeyRawRep = SecKeyCopyExternalRepresentation(rsaSecKeyPublic, &publicExternalRepError) as? Data else {
        XCTFail("Failed to copy external representation for RSA SecKey")
        return
      }

      /// Let's grab the external representation of the private key
      var privateExternalRepError: Unmanaged<CFError>?
      guard let privateRSASecKeyRawRep = SecKeyCopyExternalRepresentation(rsaSecKey, &privateExternalRepError) as? Data else {
        XCTFail("Failed to copy external representation for RSA SecKey")
        return
      }

      var template = RSASecKeyTests.FixtureTemplate
      template = template.replacingOccurrences(of: "{{KEY_SIZE}}", with: "\(keySize)")
      template = template.replacingOccurrences(of: "{{PUBLIC_DER}}", with: "\(publicRSASecKeyRawRep.base64EncodedString())")
      template = template.replacingOccurrences(of: "{{PRIVATE_DER}}", with: "\(privateRSASecKeyRawRep.base64EncodedString())")

      var messageEntries: [String] = []
      for message in messages {
        var messageTemplate = RSASecKeyTests.MessageTemplate
        messageTemplate = messageTemplate.replacingOccurrences(of: "{{PLAINTEXT_MESSAGE}}", with: message)

        let encryptedMessages = try encrypt(data: message.data(using: .utf8)!, with: rsaSecKeyPublic)
        messageTemplate = messageTemplate.replacingOccurrences(of: "{{ENCRYPTED_MESSAGES}}", with: encryptedMessages.joined(separator: ",\n\t\t  "))

        let signedMessages = try sign(message: message.data(using: .utf8)!, using: rsaSecKey)
        messageTemplate = messageTemplate.replacingOccurrences(of: "{{SIGNED_MESSAGES}}", with: signedMessages.joined(separator: ",\n\t\t  "))

        messageEntries.append(messageTemplate)
      }

      template = template.replacingOccurrences(of: "{{MESSAGE_TEMPLATES}}", with: "\(messageEntries.joined(separator: ",\n\t"))")

      print("\n**************************")
      print("   Test Fixture Output      ")
      print("**************************\n")
      print(template)
      print("\n**************************")
    }

    private static let FixtureTemplate = """
      static let RSA_{{KEY_SIZE}} = Fixture(
        keySize: {{KEY_SIZE}},
        publicDER: \"\"\"
    {{PUBLIC_DER}}
    \"\"\",
        privateDER: \"\"\"
    {{PRIVATE_DER}}
    \"\"\",
        messages: [
          {{MESSAGE_TEMPLATES}}
        ]
      )
    """

    private static let MessageTemplate = """
    "{{PLAINTEXT_MESSAGE}}": (
      encryptedMessage: [
        {{ENCRYPTED_MESSAGES}}
      ],
      signedMessage: [
        {{SIGNED_MESSAGES}}
      ]
    )
    """

    private func initSecKey(rawRepresentation unsafe: Data) throws -> SecKey {
      let attributes: [String: Any] = [
        kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
        kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
        kSecAttrKeySizeInBits as String: 1024,
        kSecAttrIsPermanent as String: false
      ]

      var error: Unmanaged<CFError>?
      guard let secKey = SecKeyCreateWithData(unsafe as CFData, attributes as CFDictionary, &error) else {
        throw NSError(domain: "Error constructing SecKey from raw key data: \(error.debugDescription)", code: 0, userInfo: nil)
      }

      return secKey
    }

    // We don't support PSS yet so we skip these variants
    private func sign(message: Data, using key: SecKey) throws -> [String] {
      let algorithms: [SecKeyAlgorithm] = [
        .rsaSignatureRaw,
        //.rsaSignatureDigestPSSSHA1,
        //.rsaSignatureDigestPSSSHA224,
        //.rsaSignatureDigestPSSSHA256,
        //.rsaSignatureDigestPSSSHA384,
        //.rsaSignatureDigestPSSSHA512,
        .rsaSignatureDigestPKCS1v15Raw,
        .rsaSignatureDigestPKCS1v15SHA1,
        .rsaSignatureDigestPKCS1v15SHA224,
        .rsaSignatureDigestPKCS1v15SHA256,
        .rsaSignatureDigestPKCS1v15SHA384,
        .rsaSignatureDigestPKCS1v15SHA512,
        //.rsaSignatureMessagePSSSHA1,
        //.rsaSignatureMessagePSSSHA224,
        //.rsaSignatureMessagePSSSHA256,
        //.rsaSignatureMessagePSSSHA384,
        //.rsaSignatureMessagePSSSHA512,
        .rsaSignatureMessagePKCS1v15SHA1,
        .rsaSignatureMessagePKCS1v15SHA224,
        .rsaSignatureMessagePKCS1v15SHA256,
        .rsaSignatureMessagePKCS1v15SHA384,
        .rsaSignatureMessagePKCS1v15SHA512,
      ]

      var sigs: [String] = []

      for algo in algorithms {
        var error: Unmanaged<CFError>?

        // Sign the data
        guard let signature = SecKeyCreateSignature(
          key,
          algo,
          message as CFData,
          &error
        ) as Data?
        else {
          print("\"\(algo.rawValue)\": \"nil\",")
          sigs.append("\"\(algo.rawValue)\": \"\"")
          continue
        }

        // Throw the error if we encountered one
        if let error = error { print("\"\(algo.rawValue)\": \"\(error.takeRetainedValue())\","); continue }

        // Append the signature
        sigs.append("\"\(algo.rawValue)\": \"\(signature.base64EncodedString())\"")
      }

      return sigs
    }

    private func encrypt(data: Data, with key: SecKey) throws -> [String] {
      let algorithms: [SecKeyAlgorithm] = [
        .rsaEncryptionRaw,
        .rsaEncryptionPKCS1
      ]

      var encryptions: [String] = []

      for algo in algorithms {
        var error: Unmanaged<CFError>?
        guard let encryptedData = SecKeyCreateEncryptedData(key, algo, data as CFData, &error) as? Data else {
          print("\"\(algo.rawValue)\": \"\(error?.takeRetainedValue().localizedDescription ?? "nil")\",")
          encryptions.append("\"\(algo.rawValue)\": \"\"")
          continue
        }
        encryptions.append("\"\(algo.rawValue)\": \"\(encryptedData.base64EncodedString())\"")
      }

      return encryptions
    }
  }

#endif
