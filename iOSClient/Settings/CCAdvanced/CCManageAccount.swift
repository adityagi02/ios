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
                .onTapGesture { } // TODO: ex.Acknowledgements
                
                HStack {
                    Image("lock")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("_certificate_pn_details_", comment: ""))
                }
                .font(.system(size: 16))
                .onTapGesture { }
            })
            // Section : USER INFORMATION -------------------------------------------
            Section(header: Text(NSLocalizedString("_personal_information_", comment: "")), content: {
                // Full Name
                HStack {
                    Image("user")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("_user_full_name_", comment: ""))
                    
                    Spacer()
                    
                    Text(NSLocalizedString("_user_full_name_", comment: ""))
                        .foregroundColor(.secondary)
                }
                .font(.system(size: 16))
                // Address
                HStack {
                    Image("address")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                        .foregroundColor(.secondary)
                    
                    Text(NSLocalizedString("_user_address_", comment: ""))
                    
                    Spacer()
                    
                    Text(NSLocalizedString("_user_address_", comment: ""))
                        .foregroundColor(.secondary)
                }
                .font(.system(size: 16))
                // City + zip
                HStack {
                    Image("city")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                        .foregroundColor(.secondary)
                    
                    Text(NSLocalizedString("_user_city_", comment: ""))
                    
                    Spacer()
                    
                    Text(NSLocalizedString("_user_city_", comment: ""))
                        .foregroundColor(.secondary)
                }
                .font(.system(size: 16))
                // Country
                HStack {
                    Image("country")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                        .foregroundColor(.secondary)
                    
                    Text(NSLocalizedString("_user_country_", comment: ""))
                    
                    Spacer()
                    
                    Text(NSLocalizedString("_user_country_", comment: ""))
                        .foregroundColor(.secondary)
                }
                .font(.system(size: 16))
                // Phone
                HStack {
                    Image("phone")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                        .foregroundColor(.secondary)
                    
                    Text(NSLocalizedString("_user_phone_", comment: ""))
                    
                    Spacer()
                    
                    Text(NSLocalizedString("_user_phone_", comment: ""))
                        .foregroundColor(.secondary)
                }
                .font(.system(size: 16))
                // Email
                HStack {
                    Image("email")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                        .foregroundColor(.secondary)
                    
                    Text(NSLocalizedString("_user_email_", comment: ""))
                    
                    Spacer()
                    
                    Text(NSLocalizedString("_user_email_", comment: ""))
                        .foregroundColor(.secondary)
                }
                .font(.system(size: 16))
                // Web
                HStack {
                    Image("network")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                        .foregroundColor(.secondary)
                    
                    Text(NSLocalizedString("_user_web_", comment: ""))
                    
                    Spacer()
                    
                    Text(NSLocalizedString("_user_web_", comment: ""))
                        .foregroundColor(.secondary)
                }
                .font(.system(size: 16))
                // Twitter
                HStack {
                    Image("twitter")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                        .foregroundColor(.secondary)
                    
                    Text(NSLocalizedString("_user_twitter_", comment: ""))
                    
                    Spacer()
                    
                    Text(NSLocalizedString("_user_twitter_", comment: ""))
                        .foregroundColor(.secondary)
                }
                .font(.system(size: 16))
                
            })
        }
        .navigationBarTitle("Credentials")
    }
}

#Preview {
    CCManageAccounts()
}
