;;; lisp/my-lsp.el -*- lexical-binding: t; -*-
;;
;; LSP и документация: eldoc-mouse, lsp-mode, lsp-ui.

(use-package! eldoc-mouse
    :hook (eglot-managed-mode . eldoc-mouse-mode))

;; Reduce LSP update frequency while typing.
(after! lsp-mode
  (setq lsp-idle-delay 1.0
        lsp-progress-function #'ignore))

(after! lsp-ui
  ;; Doom отключает всплывающую документацию, включаем.
  (setq lsp-ui-doc-enable t
        ;; Показывать при наведении мыши, как в VS Code.
        lsp-ui-doc-show-with-mouse t
        ;; При движении курсора клавиатуры не показывать.
        lsp-ui-doc-show-with-cursor nil
        ;; Doom задаёт окно 35x8 символов, длинная документация
        ;; в нём обрезается, поэтому увеличиваем.
        lsp-ui-doc-max-width 100
        lsp-ui-doc-max-height 20))
