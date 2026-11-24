;;; lisp/my-workspace.el -*- lexical-binding: t; -*-
;;
;; Восстановление последнего рабочего пространства после загрузки сессии.

;;; ------------------------------------------------------------------
;;; Восстановление последнего рабочего пространства после загрузки сессии.
;;; ------------------------------------------------------------------
(defun my/last-workspace-file ()
  (expand-file-name "last-workspace" persp-save-dir))

(defun my/save-last-workspace (&rest _)
  (ignore-errors
    (with-temp-file (my/last-workspace-file)
      (insert (+workspace-current-name)))))

(defun my/restore-last-workspace (&rest _)
  (let ((file (my/last-workspace-file)))
    (when (file-readable-p file)
      (let ((name (with-temp-buffer
                    (insert-file-contents file)
                    (string-trim (buffer-string)))))
        (when (+workspace-exists-p name)
          (+workspace-switch name))))))

(after! persp-mode
  (add-hook 'persp-before-save-state-to-file-functions #'my/save-last-workspace))

(advice-add 'doom-load-session :after #'my/restore-last-workspace)
