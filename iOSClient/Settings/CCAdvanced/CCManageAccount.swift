//
//  CCManageAccount.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 27/04/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import SwiftUI

struct CCManageAccounts: View {
    @State var alias: String = ""
    var activeAccount = NCManageDatabase.shared.getActiveAccount()
    /// State to control the visibility of the Certificate PN Details  view
    @State private var showCertificatePNDetails = false
    /// State to control the visibility of the Certificate Details  view
    @State private var showCertificateDetails = false
    /// State to control the visibility of the Certificate PN View
    @State private var showCertificatePN = false
    /// State to control the visibility of the Certificate View
    @State private var showCertificate = false
    
    var body: some View {
        // Section : ACCOUNTS -------------------------------------------
        // Open Login
        Form {
            // Section : ALIAS --------------------------------------------------
            Section(content: {
                HStack {
                    Image("form-textbox")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                        .foregroundColor(.secondary)
                    TextField("", text: $alias)
                        .onSubmit { } // TODO:
                        .font(.system(size: 15))
                        .foregroundColor(Color(UIColor.label))
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .multilineTextAlignment(.trailing)
                }
                .font(.system(size: 16))
            }, header: {
                Text(NSLocalizedString("_alias_", comment: ""))
            }, footer: {
                Text(NSLocalizedString("_alias_footer_", comment: ""))
            })
            // Section : MANAGE ACCOUNT -------------------------------------------
            if !NCBrandOptions.shared.disable_manage_account {
                Section(content: {
                    if !NCBrandOptions.shared.disable_multiaccount {
                        NavigationLink(destination: AutoUploadView(model: AutoUploadModel())) { // TODO:
                            HStack {
                                Image("plus")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, height: 20)
                                Text(NSLocalizedString("_add_account_", comment: ""))
                            }
                            .font(.system(size: 16))
                        }
                    }
                    if NCGlobal.shared.capabilityUserStatusEnabled {
                        NavigationLink(destination: AutoUploadView(model: AutoUploadModel())) {
                            HStack {
                                Image("userStatusAway")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, height: 20)
                                Text(NSLocalizedString("_set_user_status_", comment: ""))
                            }
                            .font(.system(size: 16))
                        }
                    }
                    if !NCBrandOptions.shared.disable_multiaccount {
                        NavigationLink(destination: AutoUploadView(model: AutoUploadModel())) { // TODO:
                            HStack {
                                Image("users")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, height: 20)
                                Text(NSLocalizedString("_settings_account_request_", comment: ""))
                            }
                            .font(.system(size: 16))
                        }
                    }
                }, header: {
                    Text(NSLocalizedString("_manage_account_", comment: ""))
                }, footer: {
                    Text(NSLocalizedString("_alias_footer_", comment: ""))
                })
            }
            // Section : CERIFICATES -------------------------------------------
            Section(header: Text(NSLocalizedString("_certificates_", comment: "")), content: {
                HStack {
                    Image("lock")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("_certificate_details_", comment: ""))
                }
                .font(.system(size: 16))
                .onTapGesture {
                    showCertificateDetails = true
                }.sheet(isPresented: $showCertificateDetails) {
                    NCCertificateDetailsView(showText: $showCertificate, browserTitle: NSLocalizedString("_certificate_view_", comment: ""), host: AppDelegate().urlBase)
                }
                HStack {
                    Image("lock")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("_certificate_pn_details_", comment: ""))
                }
                .font(.system(size: 16))
                .onTapGesture {
                    showCertificatePNDetails = true
                }.sheet(isPresented: $showCertificatePNDetails) {
                    NCCertificateDetailsView(showText: $showCertificatePN, browserTitle: NSLocalizedString("_certificate_view_", comment: ""), host: NCBrandOptions.shared.pushNotificationServerProxy)
                }
            })
            // Section : USER INFORMATION -------------------------------------------
            Section(header: Text(NSLocalizedString("_personal_information_", comment: "")), content: {
                // Full Name
                if let activeAccount, activeAccount.displayName.count > 0 {
                    HStack {
                        Image("user")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("_user_full_name_", comment: ""))
                        Spacer()
                        Text(activeAccount.displayName)
                            .foregroundColor(.secondary)
                    }
                    .font(.system(size: 16))
                }
                // Address
                if let activeAccount, activeAccount.address.count > 0 {
                    HStack {
                        Image("address")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("_user_address_", comment: ""))
                        Spacer()
                        Text(activeAccount.address)
                            .foregroundColor(.secondary)
                    }
                    .font(.system(size: 16))
                }
                // City + zip
                if let activeAccount, activeAccount.city.count > 0 {
                    HStack {
                        Image("city")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("_user_city_", comment: ""))
                        Spacer()
                        Text(activeAccount.city)
                            .foregroundColor(.secondary)
                    }
                    .font(.system(size: 16))
                }
                // Country
                if let activeAccount, activeAccount.country.count > 0 {
                    HStack {
                        Image("country")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("_user_country_", comment: ""))
                        Spacer()
                        Text(activeAccount.country)
                            .foregroundColor(.secondary)
                    }
                    .font(.system(size: 16))
                }
                // Phone
                if let activeAccount, activeAccount.phone.count > 0 {
                    HStack {
                        Image("phone")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("_user_phone_", comment: ""))
                        Spacer()
                        Text(activeAccount.phone)
                            .foregroundColor(.secondary)
                    }
                    .font(.system(size: 16))
                }
                // Email
                if let activeAccount, activeAccount.email.count > 0 {
                    HStack {
                        Image("email")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("_user_email_", comment: ""))
                        Spacer()
                        Text(activeAccount.email)
                            .foregroundColor(.secondary)
                    }
                    .font(.system(size: 16))
                }
                // Web
                if let activeAccount, activeAccount.website.count > 0 {
                    HStack {
                        Image("network")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("_user_web_", comment: ""))
                        Spacer()
                        Text(activeAccount.website)
                            .foregroundColor(.secondary)
                    }
                    .font(.system(size: 16))
                }
                // Twitter
                if let activeAccount, activeAccount.website.count > 0 {
                    HStack {
                        Image("twitter")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("_user_twitter_", comment: ""))
                        Spacer()
                        Text(activeAccount.website)
                            .foregroundColor(.secondary)
                    }
                    .font(.system(size: 16))
                }
            })
        }
        .navigationBarTitle("Credentials")
    }
}

#Preview {
    CCManageAccounts()
}
