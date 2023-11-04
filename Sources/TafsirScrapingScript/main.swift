#!/usr/bin/env swift

import Foundation
import Kanna

struct Chapter: Codable {
    let number: Int
    let name: String
    let placeOfRevelation: String
    let numberOfVerses: Int
    let verses: [Verse]
}

struct Verse: Codable {
    let number: Int
    let text: String
    let originalText: String
    let commentary: String
}

func scrapeChapters() {
        guard let url = URL(string: "https://tefsir.ba/sure") else {
            print("Invalid URL")
            return
        }

        do {
            let html = try String(contentsOf: url)

            guard let doc = try? HTML(html: html, encoding: .utf8) else {
                print("Failed to parse HTML")
                return
            }

            // Extract the parent element containing chapter links
            guard let chapterParentElement = doc.css("article").first else {
                print("Chapter parent element not found")
                return
            }

            let chapterLinks = chapterParentElement.css("a")

            var chapters: [Chapter] = []

            for (index, chapterLink) in chapterLinks.prefix(114).enumerated() {
                guard let chapterName = chapterLink.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                      let chapterURLString = chapterLink["href"],
                      let chapterURL = URL(string: chapterURLString) else {
                    print("Failed to extract chapter information")
                    continue
                }

                let formattedChapterName = chapterName.replacingOccurrences(of: #"^\d+.\s+"#, with: "", options: .regularExpression)

                if let chapterData = scrapeChapter(url: chapterURL, number: index + 1, name: formattedChapterName) {
                    chapters.append(chapterData)
                }
            }
            
            // Get the URL of the directory containing main.swift
            let mainFileURL = URL(fileURLWithPath: #file)
            let mainDirectoryURL = mainFileURL.deletingLastPathComponent()
            
            // Create a URL for the tafsir.json file in the same directory as main.swift
            let tafsirJSONURL = mainDirectoryURL.appendingPathComponent("tafsir.json")
            
            // Encode the JSON data
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let jsonData = try encoder.encode(chapters)
                
                // Print the JSON data (for debugging purposes)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print("JSON data:")
                    print(jsonString)
                } else {
                    print("Failed to convert JSON data to string.")
                }
                
                // Write JSON data to the tafsir.json file
                do {
                    try jsonData.write(to: tafsirJSONURL)
                    print("File path: \(tafsirJSONURL.path)")
                } catch {
                    print("Failed to write JSON data to file: \(error)")
                }
                
            } catch {
                print("Error: \(error)")
            }

        } catch {
            print("Error: \(error)")
        }
}

func scrapeChapter(url: URL, number: Int, name: String) -> Chapter? {
    for _ in 1...3 {
        do {
            let chapterHTML = try String(contentsOf: url)
            
            guard let chapterDoc = try? HTML(html: chapterHTML, encoding: .utf8) else {
                print("Failed to parse chapter HTML")
                return nil
            }
            
            // Extract the parent element containing verse links
            guard let verseParentElement = chapterDoc.css("article").first else {
                print("Verse parent element not found")
                return nil
            }
            
            // Extract place of revelation from the chapter
            var placeOfRevelation: String = ""
            if let postSubtitleElement = chapterDoc.css("h3.post-subtitle").first {
                let postSubtitleText = postSubtitleElement.text ?? ""
                let parts = postSubtitleText.split(separator: " ")
                if let lastWord = parts.last {
                    placeOfRevelation = String(lastWord.dropLast()) + "a"
                }
            }
            
            // Extract the number of verses in the chapter
            var numberOfVerses: Int = 0
            if let postMetaElement = verseParentElement.css("p.post-meta").first {
                let postMetaText = postMetaElement.text ?? ""
                
                // Split the postMetaText by spaces
                let components = postMetaText.components(separatedBy: " ")
                
                // Find the index of "ima" in the array
                if let index = components.firstIndex(of: "ima") {
                    // Check if there is a valid number after "ima"
                    if index + 1 < components.count {
                        let numberString = components[index + 1]
                        if let number = Int(numberString) {
                            numberOfVerses = number
                        }
                    }
                }
            }
            
            // Extract verse links from the chapter
            let verseLinks = verseParentElement.css("a").filter { $0["target"] != "_blank" }
            
            var verses: [Verse] = []
            for (index, verseLink) in verseLinks.enumerated() {
                if let verseURLString = verseLink["href"],
                   let verseURL = URL(string: verseURLString),
                   let verseHTML = try? String(contentsOf: verseURL),
                   let verseDoc = try? HTML(html: verseHTML, encoding: .utf8) {
                    let verseNumber = index + 1
                    let verseText = verseLink.text?.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: #"^\d+.\s+"#, with: "", options: .regularExpression) ?? ""
                    
                    // Extract the original text of the verse
                    let originalText = verseDoc.css("article p[align='right']").first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    
                    // Extract commentary text from the verse
                    if let commentaryDiv = verseDoc.css("article").first {
                        let commentaryElements = commentaryDiv.css("p, h2")
                        var commentaryText = ""
                        var pTagCounter = 0
                        for element in commentaryElements {
                            if element["class"] == "tag" {
                                break
                            }
                            
                            if element.tagName == "p" {
                                pTagCounter += 1
                                if pTagCounter <= 4 {
                                    continue
                                }
                                let trimmedText = element.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                                if !trimmedText.isEmpty {
                                    commentaryText += "\(trimmedText)\n"
                                }
                            } else if element.tagName == "h2" {
                                let trimmedText = element.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                                if !trimmedText.isEmpty {
                                    commentaryText += "\(trimmedText)\n"
                                }
                            }
                        }
                        
                        let verse = Verse(number: verseNumber, text: verseText, originalText: originalText, commentary: commentaryText)
                        verses.append(verse)
                    }
                } else {
                    print("Failed to fetch HTML content for verse: \(verseLink["href"] ?? "")")
                }
            }
            
            let chapter = Chapter(number: number, name: name, placeOfRevelation: placeOfRevelation, numberOfVerses: numberOfVerses, verses: verses)
            return chapter
            
        } catch {
            print("Error: \(error)")
            sleep(1)
        }
    }
    return nil
}
scrapeChapters()
