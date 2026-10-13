import Foundation

enum NorthstarWorkflowType: String, Codable {

    case website
    case app
    case branding
    case learning
}

enum NorthstarWorkflowStage: String, Codable {

    case discovery = "Discovery"
    case brief = "Brief"
    case sitemap = "Sitemap"
    case wireframe = "Wireframe"
    case build = "Build"
    case testing = "Testing"
    case launch = "Launch"
}

struct NorthstarWorkflow: Codable {

    var projectName: String

    var workflowType: NorthstarWorkflowType

    var currentStage: NorthstarWorkflowStage

    var progress: Int

    var nextRecommendedAction: String
}
