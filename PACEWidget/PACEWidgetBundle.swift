//
//  PACEWidgetBundle.swift
//  PACEWidget
//
//  Widget bundle registering PACEPrimaryGoalWidget.
//

import WidgetKit
import SwiftUI

@main
struct PACEWidgetBundle: WidgetBundle {
    var body: some Widget {
        PACEPrimaryGoalWidget()
    }
}
