;;; lisp/my-folds.el -*- lexical-binding: t; -*-
;;
;; Сворачивание блоков: hs-indent-fold и запоминание свёрнутого между сеансами.

;;; ------------------------------------------------------------------
;;; Прочее
;;; ------------------------------------------------------------------
(use-package! hs-indent-fold
    :hook (prog-mode . hs-indent-fold-mode))

;;; ------------------------------------------------------------------
;;; Запоминание свёрнутых блоков (hideshow) между сеансами.
;;; ------------------------------------------------------------------
(defvar my/hs-folds-file (expand-file-name "hs-folds.eld" doom-data-dir)
  "Файл, где хранятся свёрнутые блоки по файлам.")
(defvar my/hs-folds--table nil)
(defvar my/hs-folds--loaded nil)

(defun my/hs-folds--load ()
  (unless my/hs-folds--loaded
    (setq my/hs-folds--loaded t
          my/hs-folds--table
          (when (file-readable-p my/hs-folds-file)
            (ignore-errors
              (with-temp-buffer
                (insert-file-contents my/hs-folds-file)
                (read (current-buffer))))))))

(defun my/hs-folds--write ()
  (ignore-errors
    (make-directory (file-name-directory my/hs-folds-file) t)
    (with-temp-file my/hs-folds-file
      (let (print-length print-level)
        (prin1 my/hs-folds--table (current-buffer))))))

(defun my/hs-folds--line-text ()
  (string-trim (buffer-substring-no-properties
                (line-beginning-position) (line-end-position))))

(defun my/hs-folds--collect ()
  "Список (СТРОКА . ТЕКСТ) для всех свёрнутых блоков текущего буфера."
  (save-restriction
    (widen)
    (let (res)
      (dolist (ov (overlays-in (point-min) (point-max)))
        (when (and (overlay-get ov 'hs)
                   (eq (overlay-get ov 'invisible) 'hs))
          (save-excursion
            (goto-char (overlay-start ov))
            (push (cons (line-number-at-pos) (my/hs-folds--line-text)) res))))
      (sort res (lambda (a b) (< (car a) (car b)))))))

(defun my/hs-folds--save-buffer ()
  (when (and buffer-file-name (bound-and-true-p hs-minor-mode))
    (my/hs-folds--load)
    (let ((key (file-truename buffer-file-name))
          (folds (my/hs-folds--collect)))
      (setq my/hs-folds--table
            (cl-remove key my/hs-folds--table :key #'car :test #'equal))
      (when folds
        (push (cons key folds) my/hs-folds--table)))))

(defun my/hs-folds--on-kill-buffer ()
  (when (and buffer-file-name (bound-and-true-p hs-minor-mode))
    (my/hs-folds--save-buffer)
    (my/hs-folds--write)))

(defun my/hs-folds--on-kill-emacs ()
  (dolist (b (buffer-list))
    (with-current-buffer b (my/hs-folds--save-buffer)))
  (my/hs-folds--write))

(defun my/hs-folds--restore ()
  "Свернуть блоки, которые были свёрнуты в прошлый раз."
  (when (and hs-minor-mode buffer-file-name)
    (my/hs-folds--load)
    (let ((folds (cdr (assoc (file-truename buffer-file-name)
                             my/hs-folds--table))))
      (when folds
        (save-excursion
          (save-restriction
            (widen)
            (dolist (f (reverse folds))
              (goto-char (point-min))
              (when (and (zerop (forward-line (1- (car f))))
                         (string= (my/hs-folds--line-text) (cdr f)))
                (ignore-errors (hs-hide-block))))))))))

(add-hook 'kill-buffer-hook #'my/hs-folds--on-kill-buffer)
(add-hook 'kill-emacs-hook #'my/hs-folds--on-kill-emacs)
(add-hook 'hs-minor-mode-hook #'my/hs-folds--restore)
