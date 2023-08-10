//
//  NCEndToEndMetadataV20.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 09/08/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import NextcloudKit
import Gzip

extension NCEndToEndMetadata {

    // --------------------------------------------------------------------------------------------
    // MARK: Ecode JSON Metadata V2.0
    // --------------------------------------------------------------------------------------------

    func encoderMetadataV20(account: String, serverUrl: String, userId: String) -> (metadata: String?, signature: String?) {

        guard let privateKey = CCUtility.getEndToEndPrivateKey(account),
              let publicKey = CCUtility.getEndToEndPublicKey(account),
              let certificate = CCUtility.getEndToEndCertificate(account) else {
            return (nil, nil)
        }

        let e2eEncryptions = NCManageDatabase.shared.getE2eEncryptions(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl))


        var usersCodable: [E2eeV20.Users] = []
        var metadataCodable: E2eeV20.Metadata = E2eeV20.Metadata(ciphertext: "", nonce: "", authenticationTag: "")
        var filedropCodable: [String: E2eeV20.Filedrop] = [:]

        var encryptedMetadataKey: String?
        var e2eeJson: String?

        if let user = NCManageDatabase.shared.getE2EUsersV2(account: account, serverUrl: serverUrl, userId: userId) {
            encryptedMetadataKey = user.encryptedMetadataKey
        } else {
            if let keyGenerated = NCEndToEndEncryption.sharedManager()?.generateKey() as? NSData,
               let key = keyGenerated.base64EncodedString().data(using: .utf8)?.base64EncodedString(),
               let metadataKeyEncrypted = NCEndToEndEncryption.sharedManager().encryptAsymmetricString(key, publicKey: nil, privateKey: privateKey) {
                encryptedMetadataKey = metadataKeyEncrypted.base64EncodedString()
                NCManageDatabase.shared.addE2EUsersV2(account: account, serverUrl: serverUrl, userId: userId, certificate: certificate, encryptedFiledropKey: nil, encryptedMetadataKey: encryptedMetadataKey, decryptedFiledropKey: nil, decryptedMetadataKey: nil, filedropKey: nil, metadataKey: nil)
            }
        }

        guard let encryptedMetadataKey else { return (nil, nil) }

        // Create E2eeV20.Users
        if let e2eUsers = NCManageDatabase.shared.getE2EUsersV2(account: account, serverUrl: serverUrl) {
            for user in e2eUsers {
                usersCodable.append(E2eeV20.Users(userId: user.userId, certificate: user.certificate, encryptedMetadataKey: user.encryptedMetadataKey, encryptedFiledropKey: user.encryptedFiledropKey))
            }
        }

        // Counter
        if NCManageDatabase.shared.getE2eMetadataV2(account: account, serverUrl: serverUrl) == nil {
            NCManageDatabase.shared.addE2eMetadataV2(account: account, serverUrl: serverUrl, keyChecksums: nil, deleted: false, counter: 1, folders: nil, version: "2.0nil")
        } else {
            NCManageDatabase.shared.incrementCounterE2eMetadataV2(account: account, serverUrl: serverUrl)
        }

        // Create ciphertext


        for e2eEncryption in e2eEncryptions {

            if e2eEncryption.blob == "files" {
                let encrypted = E2eeV12.Encrypted(key: e2eEncryption.key, filename: e2eEncryption.fileName, mimetype: e2eEncryption.mimeType)

            }
        }

        let e2eeCodable = E2eeV20(metadata: metadataCodable, users: usersCodable, filedrop: filedropCodable, version: "2.0")
        do {
            let data = try JSONEncoder().encode(e2eeCodable)
            data.printJson()
            e2eeJson = String(data: data, encoding: .utf8)
        } catch let error {
            print("Serious internal error in encoding e2ee (" + error.localizedDescription + ")")
            return (nil, nil)
        }

        // Signature
        var signature: String?

        if let e2eeJson {
            let dataMetadata = Data(base64Encoded: "e2eeJson")
            if let signatureData = NCEndToEndEncryption.sharedManager().generateSignatureCMS(dataMetadata, certificate: certificate, privateKey: CCUtility.getEndToEndPrivateKey(account), publicKey: publicKey, userId: userId) {
                signature = signatureData.base64EncodedString()
            }
        }
        return (e2eeJson, signature)
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Decode JSON Metadata V2.0
    // --------------------------------------------------------------------------------------------

    func decoderMetadataV20(_ json: String, serverUrl: String, account: String, urlBase: String, userId: String, ownerId: String?) -> NKError {

        guard let data = json.data(using: .utf8) else {
            return NKError(errorCode: NCGlobal.shared.errorE2EE, errorDescription: "Error decoding JSON")
        }

        func addE2eEncryption(fileNameIdentifier: String, filename: String, authenticationTag: String, key: String, initializationVector: String, metadataKey: String, mimetype: String) {

            if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND fileName == %@", account, fileNameIdentifier)) {

                let object = tableE2eEncryption()

                object.account = account
                object.authenticationTag = authenticationTag
                object.blob = "files"
                object.fileName = filename
                object.fileNameIdentifier = fileNameIdentifier
                object.fileNamePath = CCUtility.returnFileNamePath(fromFileName: filename, serverUrl: serverUrl, urlBase: urlBase, userId: userId, account: account)
                object.key = key
                object.initializationVector = initializationVector
                object.metadataKey = metadataKey
                object.mimeType = mimetype
                object.serverUrl = serverUrl

                // Write file parameter for decrypted on DB
                NCManageDatabase.shared.addE2eEncryption(object)

                // Update metadata on tableMetadata
                metadata.fileNameView = filename

                let results = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: filename, mimeType: metadata.contentType, directory: metadata.directory)

                metadata.contentType = results.mimeType
                metadata.iconName = results.iconName
                metadata.classFile = results.classFile

                NCManageDatabase.shared.addMetadata(metadata)
            }
        }

        let decoder = JSONDecoder()
        let privateKey = CCUtility.getEndToEndPrivateKey(account)

        do {
            let json = try decoder.decode(E2eeV20.self, from: data)

            let metadata = json.metadata
            let users = json.users
            let filedrop = json.filedrop
            let version = json.version as String? ?? "2.0"

            // DATA
            NCManageDatabase.shared.deleteE2eMetadataV2(account: account, serverUrl: serverUrl)
            NCManageDatabase.shared.deleteE2EUsersV2(account: account, serverUrl: serverUrl)
            NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl))

            //
            // users
            //

            for user in users {

                var decryptedMetadataKey: Data?
                var decryptedFiledropKey: Data?
                var metadataKey: String?
                var filedropKey: String?

                if let encryptedMetadataKey = user.encryptedMetadataKey {
                    let data = Data(base64Encoded: encryptedMetadataKey)
                    if let decrypted = NCEndToEndEncryption.sharedManager().decryptAsymmetricData(data, privateKey: privateKey) {
                        decryptedMetadataKey = decrypted
                        metadataKey = decrypted.base64EncodedString()
                    }
                }

                if let encryptedFiledropKey = user.encryptedFiledropKey {
                    let data = Data(base64Encoded: encryptedFiledropKey)
                    if let decrypted = NCEndToEndEncryption.sharedManager().decryptAsymmetricData(data, privateKey: privateKey) {
                        decryptedFiledropKey = decrypted
                        filedropKey = decrypted.base64EncodedString()
                    }
                }

                NCManageDatabase.shared.addE2EUsersV2(account: account, serverUrl: serverUrl, userId: user.userId, certificate: user.certificate, encryptedFiledropKey: user.encryptedFiledropKey, encryptedMetadataKey: user.encryptedMetadataKey, decryptedFiledropKey: decryptedFiledropKey, decryptedMetadataKey: decryptedMetadataKey, filedropKey: filedropKey, metadataKey: metadataKey)
            }

            //
            // metadata
            //

            if let tableE2eUsersV2 = NCManageDatabase.shared.getE2EUsersV2(account: account, serverUrl: serverUrl, userId: userId),
               let metadataKey = tableE2eUsersV2.metadataKey,
               let decryptedMetadataKey = tableE2eUsersV2.decryptedMetadataKey {
                if let decrypted = NCEndToEndEncryption.sharedManager().decryptPayloadFile(metadata.ciphertext, key: metadataKey, initializationVector: metadata.nonce, authenticationTag: metadata.authenticationTag) {
                    if decrypted.isGzipped {
                        do {
                            let data = try decrypted.gunzipped()
                            if let jsonText = String(data: data, encoding: .utf8) {
                                print(jsonText)
                            }

                            let json = try decoder.decode(E2eeV20.ciphertext.self, from: data)  // JSONSerialization.jsonObject(with: data) as? [String: AnyObject] {

                            // Checksums
                            if let keyChecksums = json.keyChecksums,
                                let hash = NCEndToEndEncryption.sharedManager().createSHA256(from: decryptedMetadataKey),
                                !keyChecksums.contains(hash) {
                                return NKError(errorCode: NCGlobal.shared.errorE2EEKeyChecksums, errorDescription: NSLocalizedString("_e2ee_checksums_error_", comment: ""))
                            }

                            NCManageDatabase.shared.addE2eMetadataV2(account: account, serverUrl: serverUrl, keyChecksums: json.keyChecksums, deleted: json.deleted, counter: json.counter, folders: json.folders, version: version)

                            if let files = json.files {
                                for file in files {
                                    addE2eEncryption(fileNameIdentifier: file.key, filename: file.value.filename, authenticationTag: file.value.authenticationTag, key: file.value.key, initializationVector: file.value.nonce, metadataKey: metadataKey, mimetype: file.value.mimetype)
                                }
                            }

                            if let folders = json.folders {
                                for folder in folders {
                                    addE2eEncryption(fileNameIdentifier: folder.key, filename: folder.value, authenticationTag: metadata.authenticationTag, key: metadataKey, initializationVector: metadata.nonce, metadataKey: metadataKey, mimetype: "httpd/unix-directory")
                                }
                            }

                        } catch let error {
                            return NKError(error: error)
                        }
                    } else {
                        return NKError(errorCode: NCGlobal.shared.errorE2EE, errorDescription: "Error unzip ciphertext")
                    }
                } else {
                    return NKError(errorCode: NCGlobal.shared.errorE2EE, errorDescription: "Error decrypt ciphertext")
                }
            }
        } catch let error {
            return NKError(errorCode: NCGlobal.shared.errorE2EE, errorDescription: error.localizedDescription)
        }

        return NKError()
    }
}

/* TEST CMS

if let cmsData = NCEndToEndEncryption.sharedManager().generateSignatureCMS(data, certificate: CCUtility.getEndToEndCertificate(account), privateKey: CCUtility.getEndToEndPrivateKey(account), publicKey: CCUtility.getEndToEndPublicKey(account), userId: userId) {

    let cms = cmsData.base64EncodedString()
    print(cms)

    let cmsTest = "MIAGCSqGSIb3DQEHAqCAMIACAQExCzAJBgUrDgMCGgUAMAsGCSqGSIb3DQEHAaCAMIIDpzCCAo+gAwIBAgIBADANBgkqhkiG9w0BAQUFADBuMRowGAYDVQQDDBF3d3cubmV4dGNsb3VkLmNvbTESMBAGA1UECgwJTmV4dGNsb3VkMRIwEAYDVQQHDAlTdHV0dGdhcnQxGzAZBgNVBAgMEkJhZGVuLVd1ZXJ0dGVtYmVyZzELMAkGA1UEBhMCREUwHhcNMTcwOTI2MTAwNDMwWhcNMzcwOTIxMTAwNDMwWjBuMRowGAYDVQQDDBF3d3cubmV4dGNsb3VkLmNvbTESMBAGA1UECgwJTmV4dGNsb3VkMRIwEAYDVQQHDAlTdHV0dGdhcnQxGzAZBgNVBAgMEkJhZGVuLVd1ZXJ0dGVtYmVyZzELMAkGA1UEBhMCREUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDsn0JKS/THu328z1IgN0VzYU53HjSX03WJIgWkmyTaxbiKpoJaKbksXmfSpgzVGzKFvGfZ03fwFrN7Q8P8R2e8SNiell7mh1TDw9/0P7Bt/ER8PJrXORo+GviKHxaLr7Y0BJX9i/nW/L0L/VaE8CZTAqYBdcSJGgHJjY4UMf892ZPTa9T2Dl3ggdMZ7BQ2kiCiCC3qV99b0igRJGmmLQaGiAflhFzuDQPMifUMq75wI8RSRPdxUAtjTfkl68QHu7Umyeyy33OQgdUKaTl5zcS3VSQbNjveVCNM4RDH1RlEc+7Wf1BY8APqT6jbiBcROJD2CeoLH2eiIJCi+61ZkSGfAgMBAAGjUDBOMB0GA1UdDgQWBBTFrXz2tk1HivD9rQ75qeoyHrAgIjAfBgNVHSMEGDAWgBTFrXz2tk1HivD9rQ75qeoyHrAgIjAMBgNVHRMEBTADAQH/MA0GCSqGSIb3DQEBBQUAA4IBAQARQTX21QKO77gAzBszFJ6xVnjfa23YZF26Z4X1KaM8uV8TGzuNJA95XmReeP2iO3r8EWXS9djVCD64m2xx6FOsrUI8HZaw1JErU8mmOaLAe8q9RsOm9Eq37e4vFp2YUEInYUqs87ByUcA4/8g3lEYeIUnRsRsWsA45S3wD7wy07t+KAn7jyMmfxdma6hFfG9iN/egN6QXUAyIPXvUvlUuZ7/BhWBj/3sHMrF9quy9Q2DOI8F3t1wdQrkq4BtStKhciY5AIXz9SqsctFHTv4Lwgtkapoel4izJnO0ZqYTXVe7THwri9H/gua6uJDWH9jk2/CiZDWfsyFuNUuXvDSp05AAAxggIlMIICIQIBATBzMG4xGjAYBgNVBAMMEXd3dy5uZXh0Y2xvdWQuY29tMRIwEAYDVQQKDAlOZXh0Y2xvdWQxEjAQBgNVBAcMCVN0dXR0Z2FydDEbMBkGA1UECAwSQmFkZW4tV3VlcnR0ZW1iZXJnMQswCQYDVQQGEwJERQIBADAJBgUrDgMCGgUAoIGIMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTIzMDUxMDA4NDYxOVowIwYJKoZIhvcNAQkEMRYEFKlnk+/ov3trKM1XlXzkC65w0BgeMCkGCSqGSIb3DQEJNDEcMBowCQYFKw4DAhoFAKENBgkqhkiG9w0BAQEFADANBgkqhkiG9w0BAQEFAASCAQAvEpKP2xYZh8C3baa9CXumMaUrtp5Ez0nKuFAoQEDMxRDsqoRnKDiJQDITaG4s79Pxj61OUU2YTyM5BATCP6Hag/mqvTEXyPy06E09bcGjNoeZi/unCCyuc77M3rlUOgdP03l+BxQ0lPDlX2N2cAhiDzsMiAbcYhrsYo9aX2ue4O3emp4InfHqVEQaMxsVb0OZH1coxazvGLk5UougrGESigbFhZq2CLMpo/B2WU774YaZ2TRbpDObPl5wl4dV43pPmIQtp7Z90Io93G7JthFgrVNVerIrAyiqrZSLAGTzIRdhvwolf1Ole87bP8zrlb6oHvZt0DqOtOP0fk9wY9ibAAAAAAAA"

    let data = Data(base64Encoded: cmsTest)
    NCEndToEndEncryption.sharedManager().verifySignatureCMS(data, data: nil, publicKey: CCUtility.getEndToEndPublicKey(account), userId: userId)
}
 */
