;; This file contains the core configuration for the Helix editor, written in
;; Steel, a dialect of Scheme. It is responsible for loading packages, defining
;; custom commands, and setting up the overall editor environment.

;; Import necessary modules from the Helix Steel API.
;; `helix/editor.scm` provides functions for interacting with the editor's state.
;; `helix/commands.scm` provides access to built-in Helix commands.
;; `helix/static.scm` provides static utility functions for Helix.
;; `cogs/package.scm` is a custom package for managing Steel packages.
(require "helix/editor.scm")
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))
(require "cogs/package.scm")

;; Load the helix-ext package, which provides additional functionality for
;; interacting with the Helix editor, such as `hx.cx->pos`.
(require "mattwparas-helix-package/cogs/helix-ext.scm")

;; @doc
;; Specialized shell implementation, where % is a wildcard for the current file.
;; This allows for running shell commands on the currently focused file.
;;
;; Usage: `:shx <command> %` will execute the command with the current file path.
(define (shx cx . args)
  ;; Replace the % with the current file path in the arguments.
  (define expanded
    (map (lambda (x)
           (if (equal? x "%")
               (current-path cx)
               x))
         args))
  ;; Execute the shell command with the expanded arguments.
  (apply helix.run-shell-command expanded))

;; @doc
;; Adds the current file to git.
;; This command simplifies adding the currently open file to the git staging area.
;;
;; Usage: `:git-add`
(define (git-add cx)
  (shx cx "git" "add" "%"))

;; @doc
;; Gets the path of the currently focused file.
;; This utility function retrieves the absolute path of the file in the active editor buffer.
(define (current-path cx)
  (let* ([focus (editor-focus)]
         [focus-doc-id (editor->doc-id focus)])
    (editor-document->path focus-doc-id)))

;; @doc
;; Open the helix.scm file.
;; This command provides a convenient way to open the current configuration file.
;;
;; Usage: `:open-helix-scm`
(define (open-helix-scm)
  (helix.open (helix.static.get-helix-scm-path)))

;; @doc
;; Opens the init.scm file.
;; This command provides a convenient way to open the initialisation script.
;;
;; Usage: `:open-init-scm`
(define (open-init-scm)
  (helix.open (helix.static.get-init-scm-path)))
