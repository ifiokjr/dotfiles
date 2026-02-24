;; This file is the entry point for the Helix editor's configuration.
;; It is responsible for loading the necessary libraries and setting up the
;; initial state of the editor.

(require-builtin steel/random as rand::)
(require "helix/configuration.scm")
(require (only-in "helix/ext.scm" evalp eval-buffer))
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))
(require (prefix-in helix.editor. "helix/editor.scm"))

;; Load the splash screen package.
(require "mattwparas-helix-package/splash.scm")

;; Show the splash screen when Helix is opened without any arguments.
(when (equal? (command-line) '("hx"))
  (show-splash)
  (equal? (command-line) '("hx ."))
  (show-splash))

;; Load the keymaps and recent files packages.
(require "mattwparas-helix-package/cogs/keymaps.scm")

;; Start the recent files snapshotting in the background.

; (recentf-snapshot)

(require "scooter/scooter.scm")

;; Set up the keybindings for "scooter" and check that it doesn't conflict with the inbuilt
(add-global-keybinding
 (hash
  "normal"
  (hash "ret"
        (hash "s"
              ':scooter ; Open find and replace with scooter plugin
              "S"
              ':scooter-new ; Open a new instance of find and replacing removing the previous instance
              ))))

; ;; Set up global keybindings for the Gemini plugin.
; ;; These keybindings allow users to interact with the auto-suggestion feature.
; (add-global-keybinding (hash "normal"
;                              (hash "V"
;                                    (hash "m"
;                                          ':select-model ; Command to select the Gemini model
;                                          "s"
;                                          ':suggest ; Command to manually trigger a suggestion
;                                          ))))

; ;; To open the recent files, you can run
; ;; :recentf-open-files

; (require "helix-file-watcher/file-watcher.scm")
; (spawn-watcher)

; ;; Leave this here as a reminder on how it can be done, but for now prefer the language.toml file.
; (define-lsp "steel-language-server" (command "steel-language-server") (args '()))
; (define-language "scheme"
;                  (language-servers '("steel-language-server"))
;                  (formatter (command "schemat")))
