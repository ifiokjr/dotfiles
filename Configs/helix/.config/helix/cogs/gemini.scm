;; This file implements a Gemini AI suggestion tool for the Helix editor.
;; It provides commands for generating code suggestions using the Gemini CLI,
;; selecting different Gemini models, and managing auto-suggestions.
;;
;; The plugin integrates with Helix's inlay hint system to display suggestions
;; directly in the editor, and allows for accepting or dismissing them via keybindings.

(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))
(require "helix/misc.scm")
(require "mattwparas-helix-package/cogs/picker.scm")
(require "mattwparas-helix-package/cogs/helix-ext.scm")
(require (only-in "helix/editor.scm" add-inlay-hint remove-inlay-hint-by-id))
(require "helix/editor.scm")
(require-builtin helix/core/text as text.)
(require-builtin steel/time)

;; A list of available Gemini models that the user can choose from.
;; This variable defines the models that will be presented in the model selection picker.
(define *gemini-models*
  '("gemini-1.5-pro" "gemini-1.5-flash"
                     "gemini-2.5-pro-preview-05-06"
                     "gemini-2.5-pro-preview-06-05"
                     "gemini-2.5-pro"
                     "gemini-2.5-flash-preview-05-20"
                     "gemini-2.5-flash"
                     "gemini-2.0-flash"))

;; The currently selected Gemini model.
;; This variable stores the name of the Gemini model that will be used for generating suggestions.
;; It is updated when the user selects a model from the picker.
(define *current-gemini-model* "gemini-2.5-flash")

;; Stores the ID of the currently displayed inlay hint.
;; This ID is used to manage (remove or update) the inlay hint in the editor.
;
; ;;@doc
;; Add a custom inline hint
(define (temporary)
  (set-status! "hardcoded inlay hint to be added!")
  (add-inlay-hint 0 "I want to test and see what this looks like!"))

;; It is set to #false when no inlay hint is active.
(define *current-inlay-id* #false)

;; A boolean flag to enable/disable auto-suggestions.
;; When set to #true, suggestions will automatically appear as the user types.
;; Defaults to #false.
(define *auto-suggest-enabled* #false)

;; Stores the last generated suggestion text.
;; This is used when the user accepts the suggestion via a keybinding.
(define *last-suggestion-text* #false)

;; Inserts the given text into the document.
;; If there is a selection, the selection is replaced with the text. Otherwise,
;; the text is inserted at the cursor's position.
;; Before inserting, it removes any active inlay hint to avoid conflicts.
(define (insert-suggestion text)
  ;; This function inserts the given text into the document.
  ;; If there is an active selection, it replaces the selection with the new text.
  ;; Otherwise, it inserts the text at the primary cursor's position.
  ;; It achieves replacement by first deleting the existing selection
  ;; and then inserting the new text.
  (when *current-inlay-id*
    (remove-inlay-hint-by-id (car *current-inlay-id*) (cdr *current-inlay-id*))
    (set! *current-inlay-id* #false))
  (let ([selection (helix.static.current_selection)])
    (if (equal? selection "")
        (helix.static.insert_string text)
        (begin
          (helix.static.delete_selection)
          (helix.static.insert_string text)))))

;; Removes the currently displayed inlay hint from the editor.
;; This function is called when the user dismisses a suggestion or accepts it.
(define (remove-current-inlay)
  (when *current-inlay-id*
    (remove-inlay-hint-by-id (car *current-inlay-id*) (cdr *current-inlay-id*))
    (set! *current-inlay-id* #false)))

;; Gets the current document content as a string.
;; This function is necessary because it's not exported from the `helix-ext`
;; module that is being used as a dependency.
(define (get-document-as-slice)
  (let* ([focus (editor-focus)]
         [focus-doc-id (editor->doc-id focus)])
    (text.rope->string (editor->text focus-doc-id))))

;; Runs a shell command and returns its standard output.
;; This function will raise an error if the command fails.
(define (run-cmd cmd . args)
  (let ([builder (command cmd args)])
    (set-piped-stdout! builder)
    ;; The ~> macro threads the value of the previous expression
    ;; into the first argument of the next expression.
    ;; `spawn-process` returns a result, which is then unwrapped by `Ok->value`.
    ;; If the result is an error, `Ok->value` will raise it.
    (~> builder spawn-process Ok->value wait->stdout Ok->value)))

;;@doc
;; Makes a request to the Gemini CLI and returns a single suggestion.
;; This function first shows a status message to the user. It then constructs
;; the `gemini` command and executes it to get one suggestion.
;; It handles errors during the suggestion generation process and displays
;; the suggestion as an inlay hint.
(define (make-gemini-request)
  (set-status! "Generating suggestion...")

  (let* ([doc (get-document-as-slice)]
         [pos (cursor-position)]
         [input-text (string-join (list (substring doc 0 pos) "<CURSOR>" (substring doc pos)))]
         [full-gemini-prompt
          (string-append
           "Only answer in code without wrapping into markdown, what would you put at the position of <CURSOR>, don't include text before or after <CURSOR>
"
           input-text)]
         [command-string
          (string-append "echo '" full-gemini-prompt "' | gemini -m " *current-gemini-model*)])
    (with-handler (lambda (err)
                    (log::info! (string-append "Error happened: " (to-string err)))
                    (set-status! (string-append "Error: " (to-string err))))
                  (let* ([suggestion (trim (run-cmd "bash" "-c" command-string))]
                         [inlay-id (add-inlay-hint pos suggestion)])
                    (log::info! pos)
                    (set! *current-inlay-id* inlay-id)
                    (set! *last-suggestion-text* suggestion)
                    (set-status! "Suggestion received.")
                    suggestion))
    (log::info! "gemini.scm: LOGGER")))

(log::info! "Where does this go?")

;;@doc
;; Shows the model selection picker.
;; This function uses the `picker-selection` component to display a list of
;; available Gemini models. When the user selects a model, the `*current-gemini-model*`
;; variable is updated and a status message is displayed.
(define (select-model)
  (push-component! (picker-selection *gemini-models*
                                     (lambda (model)
                                       (set! *current-gemini-model* model)
                                       (set-status! (string-append "Gemini model set to: " model)))
                                     #:highlight-prefix "> ")))

;;@doc
;; The `:suggest` command.
;; This command manually triggers the generation and display of an inlay hint.
(define (suggest)
  (make-gemini-request))

;;@doc
;; Add a custom inline hint
(define (tmp)
  (set-status! "hardcoded inlay hint to be added!")
  (add-inlay-hint 0 "I want to test and see what this looks like!"))

;;@doc
;; Toggles the auto-suggest feature on or off.
;; When toggled off, any active inlay hint is removed.
(define (toggle-auto-suggest)
  (set! *auto-suggest-enabled* (not *auto-suggest-enabled*))
  (if *auto-suggest-enabled*
      (set-status! "Auto-suggest enabled.")
      (set-status! "Auto-suggest disabled."))
  (when (not *auto-suggest-enabled*)
    (remove-current-inlay)))

;;@doc
;; Accepts the current suggestion and inserts it into the document.
;; This function is typically bound to a key (e.g., Tab) to allow the user
;; to quickly accept the displayed inlay hint.
(define (accept-suggestion)
  (when *last-suggestion-text*
    (insert-suggestion *last-suggestion-text*)
    (set! *last-suggestion-text* #false)
    (set-status! "Suggestion accepted.")))

;;@doc
;; Provides the public functions of this module.
;; These functions can be called as Helix commands or used by other Steel modules.
(provide select-model
         suggest
         make-gemini-request
         remove-current-inlay
         accept-suggestion
         temporary)
