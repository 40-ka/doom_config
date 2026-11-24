;;; lisp/my-debug-tmp.el -*- lexical-binding: t; -*-
;;
;; ВРЕМЕННАЯ отладка peek-box. Когда отладка не нужна, закомментируйте
;; (load! "lisp/my-debug-tmp") в config.el или удалите файл целиком.

;; ВРЕМЕННАЯ отладка 2, потом удалить.
(defun my/dbg-change (beg end len)
  (when (equal (buffer-name) "*peek-box*")
    (message "CHG %d-%d len=%d new=%S line=%S callers=%S"
             beg end len
             (buffer-substring-no-properties beg end)
             (buffer-substring-no-properties
              (line-beginning-position) (line-end-position))
             (let (r)
               (mapbacktrace
                (lambda (_e f _a _fl)
                  (when (and (symbolp f)
                             (not (memq f '(mapbacktrace let message
                                            my/dbg-change apply funcall
                                            run-hook-with-args
                                            run-hooks progn if when
                                            let* unless and or))))
                    (push f r))))
               (seq-take (nreverse r) 12)))))
(add-hook 'after-change-functions #'my/dbg-change)
