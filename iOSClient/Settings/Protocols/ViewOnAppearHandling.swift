//
//  ViewOnAppearHandling.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 17/03/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//  Author Aditya Tyagi <adityagi02@yahoo.com>
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

/// A protocol defining methods to handle view appearance events.
protocol ViewOnAppearHandling: ObservableObject {
    /// Triggered when the view appears.
    func onViewAppear()
}

typealias DefaultViewModelRepresentable = AccountUpdateHandling & ViewOnAppearHandling

/// A protocol defining methods to handle account updates.
protocol AccountUpdateHandling {
    /// Updates the account information.
    func updateAccount()
}