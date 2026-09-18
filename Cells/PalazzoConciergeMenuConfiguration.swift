//
//  PalazzoConciergeMenuConfiguration.swift
//  Binding
//
//  Demo-oppforing for Palazzo Concierge. Flaten hentes fra den deployede
//  Palazzo-tjenesten pa staging. Endepunktet er med vilje et eksplisitt
//  wss://-endepunkt: CellResolver.emitCellAtWSEndpoint bruker det ordrett og
//  makeCellBridgeEmit legger pa bridge-uuid som siste path-komponent, sa
//  ruten blir /palazzo-concierge/bridgehead/PalazzoConciergeKnowledge/<uuid>.
//  Et cell://-endepunkt ville gatt gjennom host-rutetabellen, som allerede
//  har "bridgehead" registrert for staging-verten.
//

import Foundation
import CellBase

extension ConfigurationCatalogCell {

    nonisolated static let palazzoConciergeStagingEndpoint =
        "wss://staging.haven.digipomps.org/palazzo-concierge/bridgehead/PalazzoConciergeKnowledge"

    /// Demo-bryter. Staging er standard. Sett HAVEN_PALAZZO_ENDPOINT til
    /// ws://127.0.0.1:8098/bridgehead/PalazzoConciergeKnowledge for aa kjoere
    /// mot en lokal `palazzo-concierge serve` uten aa bygge paa nytt.
    nonisolated static var palazzoConciergeEndpoint: String {
        let override = ProcessInfo.processInfo
            .environment["HAVEN_PALAZZO_ENDPOINT"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return override.isEmpty ? palazzoConciergeStagingEndpoint : override
    }

    nonisolated static func palazzoConciergeMenuConfiguration() -> CellConfiguration {
        let reference = CellReference(
            endpoint: palazzoConciergeEndpoint,
            subscribeFeed: true,
            label: "palazzo"
        )

        guard let data = palazzoConciergeSurfaceJSON.data(using: .utf8),
              var configuration = try? JSONDecoder().decode(CellConfiguration.self, from: data)
        else {
            return palazzoConciergeFallbackConfiguration(reference: reference)
        }

        configuration.cellReferences = [reference]
        return configuration
    }

    nonisolated private static func palazzoConciergeFallbackConfiguration(
        reference: CellReference
    ) -> CellConfiguration {
        var configuration = CellConfiguration(name: "Palazzo Concierge", cellReferences: [reference])
        configuration.description = "Palazzo Concierge kunne ikke lastes."
        if let data = palazzoConciergeFallbackSkeletonJSON.data(using: .utf8),
           let skeleton = try? JSONDecoder().decode(SkeletonElement.self, from: data) {
            configuration.skeleton = skeleton
        }
        return configuration
    }

    nonisolated private static let palazzoConciergeFallbackSkeletonJSON = #"""
    {
      "VStack": {
        "spacing": 8,
        "modifiers": { "padding": 16, "maxWidthInfinity": true, "hAlignment": "leading" },
        "elements": [
          { "Text": { "text": "Palazzo Concierge", "modifiers": { "fontStyle": "headline" } } },
          { "Text": { "text": "Flaten kunne ikke leses. Innholdet er utilgjengelig akkurat na." } }
        ]
      }
    }
    """#

    nonisolated private static let palazzoConciergeSurfaceJSON = #"""
{
  "uuid": "9c4a1e28-7b53-4f0a-9d61-2f8b6c0d4a17",
  "name": "Palazzo Concierge",
  "description": "Spør Palazzos concierge om meny, allergener, vin og åpningstider. Hvert svar viser hvor det kommer fra.",
  "discovery": {
    "sourceCellEndpoint": "wss://staging.haven.digipomps.org/palazzo-concierge/bridgehead/PalazzoConciergeKnowledge",
    "sourceCellName": "PalazzoConciergeKnowledge",
    "purpose": "Spør Palazzos concierge og få et svar med kilde og ferskhet.",
    "purposeDescription": "Concierge-flate for gjestespørsmål om meny, allergener, vin og åpningstider, med synlig kilde, ferskhet og krav om menneskelig kontroll.",
    "interests": ["concierge", "restaurant", "meny", "allergener", "kunnskap"],
    "menuSlots": ["surface", "concierge"]
  },
  "cellReferences": [
    {
      "endpoint": "wss://staging.haven.digipomps.org/palazzo-concierge/bridgehead/PalazzoConciergeKnowledge",
      "subscribeFeed": true,
      "label": "palazzo",
      "subscriptions": [],
      "setKeysAndValues": []
    }
  ],
  "skeleton": {
    "ScrollView": {
      "axis": "vertical",
      "modifiers": { "maxWidthInfinity": true },
      "elements": [
        {
          "VStack": {
            "spacing": 18,
            "modifiers": { "padding": 22, "maxWidthInfinity": true, "hAlignment": "leading" },
            "elements": [

              {
                "VStack": {
                  "spacing": 4,
                  "modifiers": { "maxWidthInfinity": true, "hAlignment": "leading" },
                  "elements": [
                    {
                      "Text": {
                        "text": "Palazzo Concierge",
                        "modifiers": { "fontStyle": "title2", "fontWeight": "bold", "foregroundColor": "#1C1A17" }
                      }
                    },
                    {
                      "Text": {
                        "text": "Concierge svarer bare fra kilder den kan vise til, og sier fra når noe må kontrolleres av staben før en gjest får svaret.",
                        "modifiers": { "fontStyle": "subheadline", "foregroundColor": "#6B6259" }
                      }
                    }
                  ]
                }
              },

              {
                "TextArea": {
                  "targetKeypath": "palazzo.concierge.knowledge.query",
                  "placeholder": "Skriv spørsmålet ditt og trykk Enter — for eksempel: Hva er allergenene i arancini?",
                  "minLines": 2,
                  "maxLines": 5,
                  "submitOnEnter": true,
                  "editorMode": "plain",
                  "modifiers": {
                    "padding": 14,
                    "borderWidth": 1,
                    "borderColor": "#C8BFB2",
                    "cornerRadius": 12,
                    "background": "#FDFCF9",
                    "foregroundColor": "#1C1A17",
                    "maxWidthInfinity": true
                  }
                }
              },

              {
                "VStack": {
                  "spacing": 8,
                  "modifiers": { "maxWidthInfinity": true, "hAlignment": "leading" },
                  "elements": [
                    {
                      "Text": {
                        "text": "Eller prøv et av disse",
                        "modifiers": { "fontStyle": "caption", "fontWeight": "semibold", "foregroundColor": "#6B6259" }
                      }
                    },
                    {
                      "VStack": {
                        "spacing": 6,
                        "modifiers": { "maxWidthInfinity": true, "hAlignment": "leading" },
                        "elements": [
                          {
                            "Button": {
                              "keypath": "palazzo.concierge.knowledge.query",
                              "label": "Hva slags mat serverer dere?",
                              "payload": { "query": "Hva slags mat serverer dere?", "audience": "guest" }
                            }
                          },
                          {
                            "Button": {
                              "keypath": "palazzo.concierge.knowledge.query",
                              "label": "Hva er pistasjen fra Bronte?",
                              "payload": { "query": "Hva er pistasjen fra Bronte?", "audience": "guest" }
                            }
                          },
                          {
                            "Button": {
                              "keypath": "palazzo.concierge.knowledge.query",
                              "label": "Hva er allergenene i arancini?",
                              "payload": { "query": "Hva er allergenene i arancini?", "audience": "guest" }
                            }
                          }
                        ]
                      }
                    }
                  ]
                }
              },

              {
                "VStack": {
                  "spacing": 8,
                  "modifiers": { "maxWidthInfinity": true, "hAlignment": "leading" },
                  "elements": [
                    {
                      "Text": {
                        "text": "Svar",
                        "modifiers": { "fontStyle": "headline", "fontWeight": "semibold", "foregroundColor": "#1C1A17" }
                      }
                    },
                    {
                      "List": {
                        "topic": "concierge.knowledge.answer",
                        "flowElementSkeleton": {
                          "VStack": {
                            "spacing": 10,
                            "modifiers": {
                              "padding": 16,
                              "borderWidth": 1,
                              "borderColor": "#E0D8CB",
                              "cornerRadius": 12,
                              "background": "#FDFCF9",
                              "maxWidthInfinity": true,
                              "hAlignment": "leading"
                            },
                            "elements": [
                              {
                                "Text": {
                                  "keypath": "content.answer",
                                  "modifiers": {
                                    "styleRole": "markdown",
                                    "fontStyle": "body",
                                    "foregroundColor": "#1C1A17",
                                    "maxWidthInfinity": true
                                  }
                                }
                              },
                              { "Divider": { "modifiers": { "maxWidthInfinity": true } } },
                              {
                                "Text": {
                                  "keypath": "content.citations[0].title",
                                  "modifiers": { "fontStyle": "caption", "fontWeight": "semibold", "foregroundColor": "#6B6259", "maxWidthInfinity": true }
                                }
                              },
                              {
                                "HStack": {
                                  "spacing": 6,
                                  "elements": [
                                    {
                                      "Text": {
                                        "text": "Sist kontrollert",
                                        "modifiers": { "fontStyle": "caption", "foregroundColor": "#8A8078" }
                                      }
                                    },
                                    {
                                      "Text": {
                                        "keypath": "content.last_verified",
                                        "modifiers": { "fontStyle": "caption", "fontWeight": "semibold", "foregroundColor": "#6B6259" }
                                      }
                                    }
                                  ]
                                }
                              },
                              {
                                "HStack": {
                                  "spacing": 6,
                                  "elements": [
                                    {
                                      "Text": {
                                        "text": "Kilder",
                                        "modifiers": { "fontStyle": "caption", "foregroundColor": "#8A8078" }
                                      }
                                    },
                                    {
                                      "Text": {
                                        "keypath": "content.citation_count",
                                        "modifiers": { "fontStyle": "caption", "fontWeight": "semibold", "foregroundColor": "#6B6259" }
                                      }
                                    },
                                    {
                                      "Text": {
                                        "text": "· Sikkerhet",
                                        "modifiers": { "fontStyle": "caption", "foregroundColor": "#8A8078" }
                                      }
                                    },
                                    {
                                      "Text": {
                                        "keypath": "content.confidence",
                                        "modifiers": { "fontStyle": "caption", "fontWeight": "semibold", "foregroundColor": "#6B6259" }
                                      }
                                    }
                                  ]
                                }
                              }
                            ]
                          }
                        },
                        "modifiers": { "maxWidthInfinity": true, "height": 340 }
                      }
                    }
                  ]
                }
              },

              { "Divider": { "modifiers": { "maxWidthInfinity": true } } },

              {
                "Section": {
                  "header": {
                    "Text": {
                      "text": "Kilder og kontroll",
                      "modifiers": { "fontStyle": "caption", "fontWeight": "semibold", "foregroundColor": "#8A8078" }
                    }
                  },
                  "content": [
                    {
                      "Text": {
                        "text": "Concierge svarer bare fra kilder den kan vise til. Her ser du hvilke kilder den har, hvor ferske de er, og hvordan et svar henger sammen med kildene sine. Svaret legger seg øverst i listen over.",
                        "modifiers": { "fontStyle": "footnote", "foregroundColor": "#6B6259", "maxWidthInfinity": true }
                      }
                    },
                    {
                      "HStack": {
                        "spacing": 8,
                        "elements": [
                          {
                            "Button": {
                              "keypath": "palazzo.freshness.ledger",
                              "label": "Ferskhet på kildene",
                              "payload": {}
                            }
                          },
                          {
                            "Button": {
                              "keypath": "palazzo.source.list",
                              "label": "Hvilke kilder finnes",
                              "payload": {}
                            }
                          },
                          {
                            "Button": {
                              "keypath": "palazzo.graph.explain",
                              "label": "Vis sammenhengen",
                              "payload": { "query": "Hva er allergenene i arancini?", "audience": "guest" }
                            }
                          }
                        ]
                      }
                    },
                    {
                      "Visualization": {
                        "kind": "network",
                        "keypath": "palazzo.graph.state.graph.visualization",
                        "actionKeypath": "palazzo.graph.neighbors",
                        "modifiers": {
                          "height": 200,
                          "maxWidthInfinity": true,
                          "borderWidth": 1,
                          "borderColor": "#E0D8CB",
                          "cornerRadius": 12
                        }
                      }
                    }
                  ],
                  "modifiers": { "maxWidthInfinity": true }
                }
              }

            ]
          }
        }
      ]
    }
  }
}
"""#
}
