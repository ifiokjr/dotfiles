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

;; CodeCompanion AI plugin
(require "/Users/ifiokjr/Developer/projects/helix/codecompanion/codecompanion.scm")

;; Configure CodeCompanion
;; Option 1: Store your API key in a file (one line, no newline)
;;   echo -n "sk-proj-..." > ~/.openai-api-key
;; Option 2: Run manually via :evalp
;;   (codecompanion-setup (hash 'provider "openai" 'api_key "sk-proj-..."))
(let ([key-file "/Users/ifiokjr/.openai-api-key"])
  (when (path-exists? key-file)
    (codecompanion-setup
      (hash 'provider "openai"
            'api_key (trim (call-with-input-file key-file
                            (lambda (f) (read-port-to-string f))))))))

;; Keybindings: ret+a for AI prompt, ret+A for quick improve
(add-global-keybinding
 (hash
  "normal"
  (hash "ret"
        (hash "a"
              ':codecompanion-inline ; Select code then press ret+a for AI transform
              "A"
              ':codecompanion-quick ; Select code then press ret+A for quick improve
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
