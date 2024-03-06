//
//  NCSettings.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 03/03/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import SwiftUI
import NextcloudKit

/// Settings view for Nextcloud
struct NCSettings: View {
    /// State to control the visibility of the acknowledgements view
    @State private var showAcknowledgements = false
    /// State to control the visibility of the Policy view
    @State private var showBrowser = false
    /// State to control the visibility of the Source Code  view
    @State private var showSourceCode = false
    
    /// Object of ViewModel of this view
    @ObservedObject var viewModel = NCSettingsViewModel()
    
    var body: some View {
        Form {
            /// `Auto Upload` Section
            Section {
                NavigationLink(destination: AutoUploadView()) {
                    HStack {
                        Image("autoUpload")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                        Text(NSLocalizedString("_settings_autoupload_", comment: ""))
                    }
                }
            }
            
            /// `Privacy` Section
            Section(content: {
                
                // Lock active YES/NO
                HStack {
                    Image("lock")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                    Text(NSLocalizedString("_lock_active_", comment: ""))
                }.onTapGesture {
                    // TODO: This requires hefty testing, will add this afterwards
                }
                
                // Enable Touch ID
                Toggle(NSLocalizedString("_enable_touch_face_id_", comment: ""), isOn: $viewModel.enableTouchID)
                    .onChange(of: viewModel.enableTouchID) { _ in
                        viewModel.updateTouchIDSetting()
                    }
                
                // Lock no screen
                Toggle(NSLocalizedString("_lock_protection_no_screen_", comment: ""), isOn: $viewModel.lockScreen) // TODO: This will also require KeychainManager, so will do it at last

                
                // Privacy screen
                Toggle(NSLocalizedString("_privacy_screen_", comment: ""), isOn: $viewModel.privacyScreen)
                    .onChange(of: viewModel.privacyScreen) { _ in
                        viewModel.updatePrivacyScreenSetting()
                    }
                
                // Reset app wrong attempts
                Toggle(NSLocalizedString("_reset_wrong_passcode_", comment: ""), isOn: $viewModel.resetWrongAttempts)
                    .onChange(of: viewModel.resetWrongAttempts) { _ in
                        viewModel.updateResetWrongAttemptsSetting()
                    }
            }, header: {
                Text(NSLocalizedString("_privacy_", comment: ""))
            }, footer: {
                Text(NSLocalizedString("_privacy_footer_", comment: ""))
                    .font(.system(size: 12))
                    .lineSpacing(1)
            })
            
            // Calender & Contacts
            if !NCBrandOptions.shared.disable_mobileconfig {
                Section(content: {
                    HStack {
                        Image("caldavcardav")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                        Text(NSLocalizedString("_mobile_config_", comment: ""))
                    }.onTapGesture {
                        viewModel.getConfigFiles()
                    }
                }, header:{
                    Text(NSLocalizedString("_calendar_contacts_", comment: ""))
                }, footer: {
                    Text(NSLocalizedString("_calendar_contacts_footer_", comment: ""))
                        .font(.system(size: 12))
                        .lineSpacing(1)
                })
            }
            
            /// `E2EEncryption` Section
            if viewModel.isE2EEEnable && NCGlobal.shared.e2eeVersions.contains(viewModel.versionE2EE) {
                Section(header: Text(NSLocalizedString("_e2e_settings_title_", comment: "")), content: {
                    HStack {
                        Image("lock")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                        Text(NSLocalizedString("_e2e_settings_", comment: ""))
                    }.onTapGesture {
                        // TODO: Handle tap gesture
                    }
                })
            }
            
            /// `Advanced` Section
            Section {
                NavigationLink(destination: EmptyView()) {
                    HStack {
                        Image("gear")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                        Text(NSLocalizedString("_advanced_", comment: ""))
                    }
                }
            }
            
            /// `Information` Section
            Section(header: Text(NSLocalizedString("_information_", comment: "")), content: {
                
                // Acknowledgements
                HStack {
                    Image("acknowledgements")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                    Text(NSLocalizedString("_acknowledgements_", comment: ""))
                }.onTapGesture {
                    showAcknowledgements = true
                }.sheet(isPresented: $showAcknowledgements) {
                    AcknowledgementsView(showText: $showAcknowledgements, browserTitle: "Acknowledgements")
                }
                
                // Terms & Privacy Conditions
                HStack {
                    Image("shield.checkerboard")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                    Text(NSLocalizedString("_privacy_legal_", comment: ""))
                }.onTapGesture {
                    showBrowser = true
                }.sheet(isPresented: $showBrowser) {
                    NCBrowserWebView(isPresented: $showBrowser, urlBase: URL(string: NCBrandOptions.shared.privacy)!, browserTitle: "Privacy Policies")
                }
                
                // Source Code
                HStack {
                    Image("gitHub")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                    Text(NSLocalizedString("_source_code_", comment: ""))
                }.onTapGesture {
                    showSourceCode = true
                }.sheet(isPresented: $showSourceCode) {
                    NCBrowserWebView(isPresented: $showSourceCode, urlBase: URL(string: NCBrandOptions.shared.sourceCode)!, browserTitle: "Source Code")
                }
            })
            
            
            /// `Watermark` Section
            Section(content: {
                
            }, footer: {
                Text("Nextcloud Liquid for iOS \(NCUtility().getVersionApp(withBuild: true)) © 2024 \n\nNextcloud Server \(NCGlobal.shared.capabilityServerVersion)\n\(NCGlobal.shared.capabilityThemingName) - \(NCGlobal.shared.capabilityThemingSlogan)")
                Text("Nextcloud Server \(NCGlobal.shared.capabilityServerVersion)")
                Text("\(NCGlobal.shared.capabilityThemingName) - \(NCGlobal.shared.capabilityThemingSlogan)")
            })
        }
        .navigationBarTitle("Settings")
    }
}


 struct NCSettings_Previews: PreviewProvider {
     static var previews: some View {
         NCSettings()
     }
 }
