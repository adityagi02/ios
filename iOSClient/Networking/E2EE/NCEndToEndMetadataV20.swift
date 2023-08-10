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

        var signature: String?

        // Signature

        let dataMetadata = Data(base64Encoded: "metadata")
        if let signatureData = NCEndToEndEncryption.sharedManager().generateSignatureCMS(dataMetadata, certificate: CCUtility.getEndToEndCertificate(account), privateKey: CCUtility.getEndToEndPrivateKey(account), publicKey: CCUtility.getEndToEndPublicKey(account), userId: userId) {
            signature = signatureData.base64EncodedString()
        }

        return (nil, signature)
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Decode JSON Metadata V2.0
    // --------------------------------------------------------------------------------------------

    func decoderMetadataV20(_ json: String, serverUrl: String, account: String, urlBase: String, userId: String, ownerId: String?) -> NKError {

        guard let data = json.data(using: .utf8) else {
            return NKError(errorCode: NCGlobal.shared.errorE2EE, errorDescription: "Error decoding JSON")
        }

        func addE2eEncryption(fileNameIdentifier: String, filename: String, authenticationTag: String?, key: String, initializationVector: String, metadataKey: String, mimetype: String) {

            if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND fileName == %@", account, fileNameIdentifier)) {

                let object = tableE2eEncryption()

                object.account = account
                object.authenticationTag = authenticationTag ?? ""
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

                NCManageDatabase.shared.setE2EUsersV2(account: account, serverUrl: serverUrl, userId: user.userId, certificate: user.certificate, encryptedFiledropKey: user.encryptedFiledropKey, encryptedMetadataKey: user.encryptedMetadataKey, decryptedFiledropKey: decryptedFiledropKey, decryptedMetadataKey: decryptedMetadataKey, filedropKey: filedropKey, metadataKey: metadataKey)
            }

            //
            // metadata
            //

            if let tableE2eUsersV2 = NCManageDatabase.shared.getE2EUsersV2(account: account, serverUrl: serverUrl, userId: userId), let metadataKey = tableE2eUsersV2.metadataKey {
                if let decrypted = NCEndToEndEncryption.sharedManager().decryptPayloadFile(metadata.ciphertext, key: tableE2eUsersV2.metadataKey, initializationVector: metadata.nonce, authenticationTag: metadata.authenticationTag) {
                    if decrypted.isGzipped {
                        do {
                            let data = try decrypted.gunzipped()
                            if let jsonText = String(data: data, encoding: .utf8) {
                                print(jsonText)
                            }
                            if let json = try JSONSerialization.jsonObject(with: data) as? [String: AnyObject] {

                                let keyChecksums = json["keyChecksums"] as? [String]
                                let deleted = json["deleted"] as? Bool ?? false
                                let counter = json["counter"] as? Int ?? 0

                                // Checksums
                                if let keyChecksums,
                                   let hash = NCEndToEndEncryption.sharedManager().createSHA256(from: tableE2eUsersV2.decryptedMetadataKey),
                                   !keyChecksums.contains(hash) {
                                    return NKError(errorCode: NCGlobal.shared.errorE2EEKeyChecksums, errorDescription: NSLocalizedString("_e2ee_checksums_error_", comment: ""))
                                }

                                NCManageDatabase.shared.setE2eMetadataV2(account: account, serverUrl: serverUrl, keyChecksums: keyChecksums, deleted: deleted, counter: counter, folders: json["folders"] as? [String: String], version: version)

                                if let files = json["files"] as? [String: Any] {
                                    for file in files {
                                        let uid = file.key
                                        if let dic = file.value as? [String: String] {
                                            if let authenticationTag = dic["authenticationTag"],
                                               let nonce = dic["nonce"],
                                               let mimetype = dic["mimetype"],
                                               let key = dic["key"],
                                               let filename = dic["filename"] {
                                                addE2eEncryption(fileNameIdentifier: uid, filename: filename, authenticationTag: authenticationTag, key: key, initializationVector: nonce, metadataKey: metadataKey, mimetype: mimetype)
                                            }
                                        }
                                    }
                                }

                                if let folders = json["folders"] as? [String: String] {
                                    for folder in folders {
                                        addE2eEncryption(fileNameIdentifier: folder.key, filename: folder.value, authenticationTag: metadata.authenticationTag, key: metadataKey, initializationVector: metadata.nonce, metadataKey: metadataKey, mimetype: "httpd/unix-directory")
                                    }
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
