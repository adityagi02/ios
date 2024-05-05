//
//  NCCertificateDetailsView.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 05/05/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import SwiftUI

struct NCCertificateDetailsView: View {
    @State private var text = ""
    @Binding var showText: Bool
    @State var fileNamePath: String = ""
    var browserTitle: String
    var host: String = ""
    let utilityFileSystem = NCUtilityFileSystem()
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(alignment: .center) {
                    Text(browserTitle)
                        .font(.title3)
                        .foregroundColor(Color(UIColor.label))
                        .padding(.leading, 8)
                }
                .padding()
                Spacer()
                Button(action: {
                    self.showText = false
                }) {
                    ZStack {
                        Image(systemName: "xmark")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 14, height: 14)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            Divider()
            if showText {
                ScrollView {
                    Text(text)
                        .padding()
                }
            }
        }
        .navigationBarTitle(Text(""), displayMode: .inline)
        .onAppear {
            loadCertificate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showText = true
            }
        }
    }
    func loadCertificate() {
        if fileNamePath.isEmpty {
            self.fileNamePath = utilityFileSystem.directoryCertificates + "/" + host + ".txt"
        }
        if FileManager.default.fileExists(atPath: fileNamePath) {
            do {
                let text = try String(contentsOfFile: fileNamePath, encoding: .utf8)
                self.text = text
            } catch {
                print("error")
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                self.showText = false
            }
        }
    }
}
