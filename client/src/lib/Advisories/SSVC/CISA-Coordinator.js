// This file is Free Software under the Apache-2.0 License
// without warranty, see README.md and LICENSES/Apache-2.0.txt for details.
//
// SPDX-License-Identifier: Apache-2.0
//
// SPDX-FileCopyrightText: 2024 German Federal Office for Information Security (BSI) <https://www.bsi.bund.de>
//  Software-Engineering: 2024 Intevation GmbH <https://intevation.de>

export default {
  decision_points: [
    {
      label: "Exploitation",
      decision_type: "simple",
      key: "E",
      options: [
        {
          label: "none",
          key: "N",
          description:
            "There is no evidence of active exploitation and no public proof of concept (PoC) of how to exploit the vulnerability."
        },
        {
          label: "poc",
          key: "P",
          description:
            "One of the following cases is true: (1) private evidence of exploitation is attested but not shared; (2) widespread hearsay attests to exploitation; (3) typical public PoC in places such as Metasploit or ExploitDB; or (4) the vulnerability has a well-known method of exploitation. Some examples of condition (4) are open-source web proxies serve as the PoC code for how to exploit any vulnerability in the vein of improper validation of TLS certificates. As another example, Wireshark serves as a PoC for packet replay attacks on ethernet or WiFi networks."
        },
        {
          label: "active",
          key: "A",
          description:
            "Shared, observable, reliable evidence that the exploit is being used in the wild by real attackers; there is credible public reporting."
        }
      ]
    },
    {
      label: "Automatable",
      key: "A",
      decision_type: "simple",
      options: [
        {
          label: "no",
          key: "N",
          description:
            "Steps 1-4 of the kill chain  cannot be reliably automated for this vulnerability for some reason. These steps are reconnaissance, weaponization, delivery, and exploitation. Example reasons for why a step may not be reliably automatable include (1) the vulnerable component is not searchable or enumerable on the network, (2) weaponization may require human direction for each target, (3) delivery may require channels that widely deployed network security configurations block, and (4) exploitation may be frustrated by adequate exploit-prevention techniques enabled by default; ASLR is an example of an exploit-prevention tool."
        },
        {
          label: "yes",
          key: "Y",
          description:
            "Steps 1-4 of the of the kill chain can be reliably automated. If the vulnerability allows unauthenticated remote code execution (RCE) or command injection, the response is likely yes."
        }
      ]
    },
    {
      label: "Technical Impact",
      key: "T",
      decision_type: "simple",
      options: [
        {
          label: "partial",
          key: "P",
          description:
            'The exploit gives the adversary limited control over, or information exposure about, the behavior of the software that contains the vulnerability. Or the exploit gives the adversary an importantly low stochastic opportunity for total control. In this context, "low" means that the attacker cannot reasonably make enough attempts to overcome the low chance of each attempt not working. Denial of service is a form of limited control over the behavior of the vulnerable component.'
        },
        {
          label: "total",
          key: "T",
          description:
            "The exploit gives the adversary total control over the behavior of the software, or it gives total disclosure of all information on the system that contains the vulnerability."
        }
      ]
    },
    {
      label: "Public Well-being Impact",
      key: "B",
      decision_type: "simple",
      options: [
        {
          label: "Minimal",
          key: "M",
          description:
            'Type of harm is "All" (Physical, Environmental,Financial,Psychological) and the associated Safety Impact Value is "None". The effect is below the threshold for all aspects described in material.'
        },
        {
          label: "Material",
          key: "A",
          description:
            'Any one or more of the conditions (Physical, Environmental,Financial,Psychological) hold and the associated Safety Impact Value is "Major". "Physical harm" means "Physical distress or injuries for users of the system OR introduces occupational safety hazards OR reduction and/or failure of cyber-physical system’s safety margins." "Environment" means "Major externalities (property damage, environmental damage, etc.) imposed on other parties." "Financial" means "Financial losses that likely lead to bankruptcy of multiple persons." "Psychological" means "Widespread emotional or psychological harm, sufficient to be cause for counselling or therapy, to populations of people."'
        },
        {
          label: "Irreversible",
          key: "I",
          description:
            'Any one or more of the following conditions hold and the associated Safety Impact Value is "Catastrophic". "Physical harm" means "Multiple fatalities likely OR loss or destruction of cyber-physical system of which the vulnerable component is a part." "Environment" means "Extreme or serious externalities (immediate public health threat, environmental damage leading to small ecosystem collapse, etc.) imposed on other parties."  "Financial" means "Social systems (elections, financial grid, etc.) supported by the software are destabilized and potentially collapse."'
        }
      ]
    },
    {
      label: "Mission Prevalence",
      key: "P",
      decision_type: "simple",
      options: [
        {
          label: "Minimal",
          key: "M",
          description:
            "Neither support nor essential apply. The vulnerable component may be used within the entities, but it is not used as a mission-essential component nor does it support (enough) mission essential functions."
        },
        {
          label: "Support",
          key: "S",
          description:
            "The operation of the vulnerable component merely supports mission essential functions for two or more entities."
        },
        {
          label: "Essential",
          key: "E",
          description:
            "The vulnerable component directly provides capabilities that constitute at least one MEF for at least one entity, and failure may (but need not) lead to overall mission failure."
        }
      ]
    },
    {
      label: "Mission & Well-being",
      key: "M",
      decision_type: "complex",
      children: [
        {
          label: "Mission Prevalence"
        },
        {
          label: "Public Well-being Impact"
        }
      ],
      options: [
        {
          label: "low",
          key: "L",
          description: "Mission Prevalence is Minimal and Public well-being impact is Minimal",
          child_combinations: [
            [
              {
                child_label: "Mission Prevalence",
                child_key: "M",
                child_option_labels: ["Minimal"],
                child_option_keys: ["M"]
              },
              {
                child_label: "Public Well-being Impact",
                child_option_labels: ["Minimal"]
              }
            ]
          ]
        },
        {
          label: "medium",
          key: "M",
          description:
            "{Mission Prevalence is Support and Public well-being is Minimal or Material} OR {Mission Prevalence is Minimal or Support and Public well-being is Material}",
          child_combinations: [
            [
              {
                child_label: "Mission Prevalence",
                child_key: "M",
                child_option_labels: ["Support"],
                child_option_keys: ["S"]
              },
              {
                child_label: "Public Well-being Impact",
                child_option_labels: ["Minimal", "Material"]
              }
            ],
            [
              {
                child_label: "Mission Prevalence",
                child_key: "M",
                child_option_labels: ["Minimal"],
                child_option_keys: ["M"]
              },
              {
                child_label: "Public Well-being Impact",
                child_option_labels: ["Material"]
              }
            ]
          ]
        },
        {
          label: "high",
          key: "H",
          description:
            "Mission Prevalence is Essential or Public well-being impact is Irreversible",
          child_combinations: [
            [
              {
                child_label: "Mission Prevalence",
                child_key: "M",
                child_option_labels: ["Essential"],
                child_option_keys: ["E"]
              },
              {
                child_label: "Public Well-being Impact",
                child_option_labels: ["Minimal", "Material", "Irreversible"]
              }
            ],
            [
              {
                child_label: "Mission Prevalence",
                child_key: "M",
                child_option_labels: ["Minimal", "Support"],
                child_option_keys: ["M", "S"]
              },
              {
                child_label: "Public Well-being Impact",
                child_option_labels: ["Irreversible"]
              }
            ]
          ]
        }
      ]
    },
    {
      label: "Decision",
      key: "D",
      decision_type: "simple",
      options: [
        {
          label: "Track",
          key: "T",
          description:
            "The vulnerability does not require attention outside of Vulnerability Management (VM) at this time.  Continue to track the situation and reassess the severity of vulnerability if necessary.",
          color: "#28a745"
        },
        {
          label: "Track*",
          key: "R",
          description:
            "Track these closely, especially if mitigation is unavailable or difficult. Recommended that analyst discuss with other ana-lysts and get a second opinion.",
          color: "#ffc107"
        },
        {
          label: "Attend",
          key: "A",
          description:
            "The vulnerability requires to be attended to by stakeholders outside VM. The action is a request to others for assistance / information / details, as well as a potential publication about the issue.",
          color: "#EE8733"
        },
        {
          label: "Act",
          key: "C",
          description:
            "The vulnerability requires immediate action by the relevant leadership. The action is a high-priority meeting among the relevant supervisors to decide how to respond.",
          color: "#dc3545"
        }
      ]
    }
  ],
  decisions_table: [
    {
      Exploitation: "none",
      Automatable: "no",
      "Technical Impact": "partial",
      "Mission & Well-being": "low",
      Decision: "Track"
    },
    {
      Decision: "Track",
      Exploitation: "none",
      Automatable: "no",
      "Technical Impact": "partial",
      "Mission & Well-being": "medium"
    },
    {
      Decision: "Track",
      Exploitation: "none",
      Automatable: "no",
      "Technical Impact": "partial",
      "Mission & Well-being": "high"
    },
    {
      Decision: "Track",
      Exploitation: "none",
      Automatable: "no",
      "Technical Impact": "total",
      "Mission & Well-being": "low"
    },
    {
      Decision: "Track",
      Exploitation: "none",
      Automatable: "no",
      "Technical Impact": "total",
      "Mission & Well-being": "medium"
    },
    {
      Decision: "Track*",
      Exploitation: "none",
      Automatable: "no",
      "Technical Impact": "total",
      "Mission & Well-being": "high"
    },
    {
      Decision: "Track",
      Exploitation: "none",
      Automatable: "yes",
      "Technical Impact": "partial",
      "Mission & Well-being": "low"
    },
    {
      Decision: "Track",
      Exploitation: "none",
      Automatable: "yes",
      "Technical Impact": "partial",
      "Mission & Well-being": "medium"
    },
    {
      Decision: "Attend",
      Exploitation: "none",
      Automatable: "yes",
      "Technical Impact": "partial",
      "Mission & Well-being": "high"
    },
    {
      Decision: "Track",
      Exploitation: "none",
      Automatable: "yes",
      "Technical Impact": "total",
      "Mission & Well-being": "low"
    },
    {
      Decision: "Track",
      Exploitation: "none",
      Automatable: "yes",
      "Technical Impact": "total",
      "Mission & Well-being": "medium"
    },
    {
      Decision: "Attend",
      Exploitation: "none",
      Automatable: "yes",
      "Technical Impact": "total",
      "Mission & Well-being": "high"
    },
    {
      Decision: "Track",
      Exploitation: "poc",
      Automatable: "no",
      "Technical Impact": "partial",
      "Mission & Well-being": "low"
    },
    {
      Decision: "Track",
      Exploitation: "poc",
      Automatable: "no",
      "Technical Impact": "partial",
      "Mission & Well-being": "medium"
    },
    {
      Decision: "Track*",
      Exploitation: "poc",
      Automatable: "no",
      "Technical Impact": "partial",
      "Mission & Well-being": "high"
    },
    {
      Decision: "Track",
      Exploitation: "poc",
      Automatable: "no",
      "Technical Impact": "total",
      "Mission & Well-being": "low"
    },
    {
      Decision: "Track*",
      Exploitation: "poc",
      Automatable: "no",
      "Technical Impact": "total",
      "Mission & Well-being": "medium"
    },
    {
      Decision: "Attend",
      Exploitation: "poc",
      Automatable: "no",
      "Technical Impact": "total",
      "Mission & Well-being": "high"
    },
    {
      Decision: "Track",
      Exploitation: "poc",
      Automatable: "yes",
      "Technical Impact": "partial",
      "Mission & Well-being": "low"
    },
    {
      Decision: "Track",
      Exploitation: "poc",
      Automatable: "yes",
      "Technical Impact": "partial",
      "Mission & Well-being": "medium"
    },
    {
      Decision: "Attend",
      Exploitation: "poc",
      Automatable: "yes",
      "Technical Impact": "partial",
      "Mission & Well-being": "high"
    },
    {
      Decision: "Track",
      Exploitation: "poc",
      Automatable: "yes",
      "Technical Impact": "total",
      "Mission & Well-being": "low"
    },
    {
      Decision: "Track*",
      Exploitation: "poc",
      Automatable: "yes",
      "Technical Impact": "total",
      "Mission & Well-being": "medium"
    },
    {
      Decision: "Attend",
      Exploitation: "poc",
      Automatable: "yes",
      "Technical Impact": "total",
      "Mission & Well-being": "high"
    },
    {
      Decision: "Track",
      Exploitation: "active",
      Automatable: "no",
      "Technical Impact": "partial",
      "Mission & Well-being": "low"
    },
    {
      Decision: "Track",
      Exploitation: "active",
      Automatable: "no",
      "Technical Impact": "partial",
      "Mission & Well-being": "medium"
    },
    {
      Decision: "Attend",
      Exploitation: "active",
      Automatable: "no",
      "Technical Impact": "partial",
      "Mission & Well-being": "high"
    },
    {
      Decision: "Track",
      Exploitation: "active",
      Automatable: "no",
      "Technical Impact": "total",
      "Mission & Well-being": "low"
    },
    {
      Decision: "Attend",
      Exploitation: "active",
      Automatable: "no",
      "Technical Impact": "total",
      "Mission & Well-being": "medium"
    },
    {
      Decision: "Act",
      Exploitation: "active",
      Automatable: "no",
      "Technical Impact": "total",
      "Mission & Well-being": "high"
    },
    {
      Decision: "Attend",
      Exploitation: "active",
      Automatable: "yes",
      "Technical Impact": "partial",
      "Mission & Well-being": "low"
    },
    {
      Decision: "Attend",
      Exploitation: "active",
      Automatable: "yes",
      "Technical Impact": "partial",
      "Mission & Well-being": "medium"
    },
    {
      Decision: "Act",
      Exploitation: "active",
      Automatable: "yes",
      "Technical Impact": "partial",
      "Mission & Well-being": "high"
    },
    {
      Decision: "Attend",
      Exploitation: "active",
      Automatable: "yes",
      "Technical Impact": "total",
      "Mission & Well-being": "low"
    },
    {
      Decision: "Act",
      Exploitation: "active",
      Automatable: "yes",
      "Technical Impact": "total",
      "Mission & Well-being": "medium"
    },
    {
      Decision: "Act",
      Exploitation: "active",
      Automatable: "yes",
      "Technical Impact": "total",
      "Mission & Well-being": "high"
    }
  ],
  lang: "en",
  version: "2.0",
  title: "CISA Coordinator v2.0.3"
};
