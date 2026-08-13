# Reach architecture policy for FrmnPlay (schema for reach 2.2.0).
# Enforced in CI via `mix reach.check --arch --smells`.
#
# Layering (dependencies point downward only):
#
#   runtime  — FrmnPlay.Application: supervision tree; may start anything
#   web      — FrmnPlayWeb.*: endpoint, router, controllers, components
#   domain   — FrmnPlay.*: business logic; must never know about the web layer
#
# Layer patterns are first-match-wins, so :runtime is listed before :domain.
# A new Phoenix context (e.g. FrmnPlay.Accounts) lands in :domain
# automatically; declare its entry-point module in boundaries[:public] and
# keep implementation modules out of that list.
[
  layers: [
    runtime: "FrmnPlay.Application",
    web: ["FrmnPlayWeb", "FrmnPlayWeb.*"],
    domain: ["FrmnPlay", "FrmnPlay.*"]
  ],
  deps: [
    forbidden: [
      # The domain must not reach up into the web layer or the runtime.
      {:domain, :web},
      {:domain, :runtime},
      # The web layer must not touch the supervision tree.
      {:web, :runtime}
    ]
  ],
  boundaries: [
    # Modules callable from outside their own namespace. Everything else
    # under a public namespace is treated as implementation detail.
    public: [
      "FrmnPlay",
      "FrmnPlay.Mailer",
      "FrmnPlayWeb",
      "FrmnPlayWeb.Endpoint",
      "FrmnPlayWeb.Router",
      "FrmnPlayWeb.Telemetry",
      "FrmnPlayWeb.Gettext",
      "FrmnPlayWeb.CoreComponents",
      "FrmnPlayWeb.Layouts"
    ],
    # Convention for future contexts: FrmnPlay.<Context>.Internal.* is
    # reachable only from within the FrmnPlay domain namespace.
    internal: ["FrmnPlay.*.Internal.*"],
    internal_callers: [
      {"FrmnPlay.*.Internal.*", ["FrmnPlay", "FrmnPlay.*"]}
    ]
  ],
  calls: [
    forbidden: [
      # Debugging calls must not ship.
      {["FrmnPlay", "FrmnPlay.*", "FrmnPlayWeb", "FrmnPlayWeb.*"],
       ["IO.inspect", "Kernel.dbg", "dbg"]},
      # The domain must not use web primitives even transitively via deps.
      # FrmnPlay.Application is the :runtime layer and supervises the endpoint.
      {["FrmnPlay", "FrmnPlay.*"], ["Plug.*", "Phoenix.*", "FrmnPlayWeb.*"],
       except: ["FrmnPlay.Application"]},
      # Nobody shells out or halts the VM from application code.
      {["FrmnPlay", "FrmnPlay.*", "FrmnPlayWeb", "FrmnPlayWeb.*"],
       ["System.cmd", "System.shell", "System.halt", ":os.cmd"]}
    ]
  ],

  # The bare FrmnPlay context stub stays free of side effects.
  effects: [
    allowed: [
      {"FrmnPlay", [:pure]}
    ]
  ],

  # Keep changed-code risk reporting at defaults, slightly stricter on
  # branchiness to flag complex functions early in a young codebase.
  risk: [
    changed: [
      many_direct_callers: 5,
      wide_transitive_callers: 10,
      branch_heavy: 6,
      high_risk_reason_count: 3
    ]
  ],

  # Structural clone detection via ex_dna; zero tolerance is enforced
  # separately in CI (`mix ex_dna --max-clones 0`).
  clone_analysis: [
    provider: :ex_dna,
    min_mass: 30,
    min_similarity: 1.0,
    max_clones: 50
  ],
  smells: [
    fixed_shape_map: [min_keys: 3, min_occurrences: 3],
    behaviour_candidate: [min_modules: 3, min_callbacks: 3]
  ],
  tests: [
    hints: [
      {"lib/frmn_play/**", ["test/frmn_play"]},
      {"lib/frmn_play_web/**", ["test/frmn_play_web"]}
    ]
  ]
]
