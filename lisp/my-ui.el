;;; lisp/my-ui.el -*- lexical-binding: t; -*-
;;
;; Внешний вид: doom-modeline и приглушение сообщений о сохранении.

;; Fixating the state line height
(after! doom-modeline
  (setq doom-modeline-height 29))

;; Убираем подсветку имени и значок изменённого буфера в строке состояния
(after! doom-modeline
  (setq doom-modeline-highlight-modified-buffer-name nil
        doom-modeline-buffer-modification-icon nil))

;; Гасим только сообщения об успешном сохранении: не показываем и не пишем
;; в *Messages*. Ошибки сохранения идут другим путём и остаются видны.
(defun my/quiet-save-msg (fn &rest args)
  (if (and (stringp (car args))
           (string-match-p "\\`Wrote \\|C written\\'" (car args)))
      (let ((inhibit-message t) (message-log-max nil))
        (apply fn args))
    (apply fn args)))
(advice-add 'message :around #'my/quiet-save-msg)
