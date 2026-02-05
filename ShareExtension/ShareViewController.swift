// Reel Mapper Share/ShareViewController.swift
import UIKit
import Social

class ShareViewController: UIViewController {
    
    private let appGroupID = "group.com.reelmapper.shared"
    
    // API Configuration for Share Extension
    private let apiBaseURL = "http://18.119.1.225:8000"  // Production URL
    
    private var activityIndicator: UIActivityIndicatorView!
    private var statusLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        extractAndSaveURL()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Activity Indicator
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        
        // Status Label
        statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Saving to Reel Mapper..."
        statusLabel.textAlignment = .center
        statusLabel.font = .systemFont(ofSize: 16, weight: .medium)
        view.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            
            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func extractAndSaveURL() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem else {
            showError("No content to share")
            return
        }
        
        // Try to get URL from attachments
        if let attachments = extensionItem.attachments {
            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier("public.url") {
                    attachment.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] (url, error) in
                        DispatchQueue.main.async {
                            if let url = url as? URL {
                                self?.saveToBackend(url: url)
                            } else {
                                self?.showError("Could not extract URL")
                            }
                        }
                    }
                    return
                }
            }
        }
        
        showError("No URL found in shared content")
    }
    
    private func saveToBackend(url: URL) {
        // Get auth token
        guard let token = getAuthToken() else {
            showError("Open Reel Mapper first to refresh your session")
            return
        }
        
        // Prepare request
        guard let apiURL = URL(string: "\(apiBaseURL)/api/v1/save-events") else {
            showError("Invalid API URL")
            return
        }
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        
        let body: [String: Any] = [
            "source_url": url.absoluteString,
            "raw_caption": NSNull(),
            "target_list_id": NSNull()
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            showError("Failed to prepare request")
            return
        }
        
        // Send request
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.showError("Network error: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.showError("Invalid response")
                    return
                }
                
                if httpResponse.statusCode == 202 || httpResponse.statusCode == 200 {
                    self?.showSuccess()
                } else if httpResponse.statusCode == 401 {
                    self?.showError("Please log in to Reel Mapper")
                } else {
                    self?.showError("Server error (\(httpResponse.statusCode))")
                }
            }
        }
        task.resume()
    }
    
    private func getAuthToken() -> String? {
        let sharedDefaults = UserDefaults(suiteName: appGroupID)
        
        // Check if token exists and is not expired
        guard let expiry = sharedDefaults?.object(forKey: "clerk_token_expiry") as? Date,
              expiry > Date(),
              let token = sharedDefaults?.string(forKey: "clerk_session_token") else {
            // Token expired or doesn't exist — user needs to open the main app first
            return nil
        }
        
        return token
    }
    
    private func showSuccess() {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        statusLabel.text = "✅ Saved to Reel Mapper!"
        
        // Auto-close after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.closeExtension()
        }
    }
    
    private func showError(_ message: String) {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        statusLabel.text = "❌ \(message)"
        
        // Auto-close after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.closeExtension()
        }
    }
    
    private func closeExtension() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
