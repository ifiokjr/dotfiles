;; This file implements a simple package management system for Steel plugins in Helix.
;; It provides functionalities to load Steel packages, keep track of loaded packages,
;; and list their exported symbols.

(require "mattwparas-helix-package/cogs/picker.scm")
(require "helix/misc.scm")
(require-builtin helix/components)

;; Provides the public functions of this module.
;; These functions can be used by other Steel modules to manage packages.
(provide load-package
         current-packages
         path->package
         module->exported
         list-packages)

;; A hash table to keep track of the loading status of each package.
;; Keys are package paths (strings) and values are booleans indicating success (#t) or failure (#f).
(define *loaded-package-registry* (hash))

;; A hash table intended for indexing packages, though currently not fully utilized.
(define *package-index* (hash))

;; Marks a package as loaded with its corresponding status.
;; This function updates the `*loaded-package-registry*`.
(define (mark-package-loaded! path status)
  (set! *loaded-package-registry* (hash-insert *loaded-package-registry* path status)))

;; Converts a canonicalized file path to its corresponding Steel package object.
;; This is an internal implementation detail and should not typically be accessed directly.
(define (path->package path)
  (eval (string->symbol (string-append "__module-mangler" (canonicalize-path path) "__%#__"))))

;; @doc
;; Fallibly requires a package from the given path.
;; If the package loading fails, it logs the error but allows the REPL to continue.
;; It updates the `*loaded-package-registry*` with the loading status.
(define (load-package path)
  (with-handler (lambda (err)
                  (log::info! (to-string "Error requiring module: " path))
                  (log::info! (to-string err))
                  (mark-package-loaded! path #f))
                (eval `(require ,path))
                (mark-package-loaded! path #t)))

;; Returns the current state of the loaded package registry.
;; This provides a snapshot of all packages that have been attempted to load and their statuses.
(define (current-packages)
  *loaded-package-registry*)

;; @doc
;; Grabs the exported symbols from the module located at the given path.
;; This function allows introspection of a loaded Steel module to see what it provides.
(define (module->exported path)
  (~> path path->package hash-keys->list))

;; @doc
;; Lists the packages that have been loaded using this package system in a picker component.
;; The picker displays the loading status of each package.
(define (list-packages)
  (push-component! (picker-selection
                    (hash-keys->list *loaded-package-registry*)
                    (lambda (_) void)
                    #:preview-function
                    (lambda (picker selection rect frame)
                      ;; TODO: Draw something more interesting here, other than the usual stuff
                      (frame-set-string! frame
                                         (+ 1 (area-x rect))
                                         (+ 1 (area-y rect))
                                         (to-string "Loaded successfully:"
                                                    (hash-get *loaded-package-registry* selection))
                                         (style)))
                    #:highlight-prefix "> ")))
