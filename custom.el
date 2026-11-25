;;; -*- lexical-binding: t -*-
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(ignored-local-variable-values
   '((eval font-lock-add-keywords nil
      `
      ((,(concat "("
                 (regexp-opt
                  '("sp-do-move-op" "sp-do-move-cl" "sp-do-put-op"
                    "sp-do-put-cl" "sp-do-del-op" "sp-do-del-cl")
                  t)
                 "\\_>")
        1 'font-lock-variable-name-face)))))
 '(lsp-crates-use-api t)
 '(lsp-log-io t)
 '(package-selected-packages '(hs-indent-fold))
 '(package-vc-selected-packages
   '((hs-indent-fold :url "https://github.com/kn66/hs-indent-fold.el.git"))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
