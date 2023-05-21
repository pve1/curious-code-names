(package.seed:define-seed-package :code-names.seed :export-capitalized t)

(in-package :code-names.seed)

;;; Wordlists

(defun Load-word-list (file)
  "Collects lines from FILE. Skips lines that start with ';' or '#'."
  (with-open-file (in (word-list file))
    (loop :for line = (read-line in nil nil)
          :while line
          :unless (or (zerop (length line))
                      (every (lambda (x)
                               (member x '(#\tab #\space)))
                             line)
                      (alexandria:starts-with #\# line)
                      (alexandria:starts-with #\; line))
            :collect line)))

(defun default-pathname-defaults ()
  *default-pathname-defaults*)

(defun default-pathname-defaults+subdir ()
  (merge-pathnames "word-lists/" *default-pathname-defaults*))

(defun system-word-list-directory ()
  (let* ((source-dir-fn (when (find-package "ASDF")
                          (find-symbol "SYSTEM-SOURCE-DIRECTORY" "ASDF")))
         (source-dir (when source-dir-fn
                       (funcall source-dir-fn
                                (string-downcase
                                 (package-name *package*))))))
    (when source-dir
      (merge-pathnames "word-lists/" source-dir))))

(defvar *Word-list-vpath*
  (list 'default-pathname-defaults
        'default-pathname-defaults+subdir
        'system-word-list-directory))

(defun try-vpath-entry (entry)
  (etypecase entry
    (string entry)
    (pathname entry)
    ((or symbol function) (funcall entry))))

(defun search-word-list-vpath (file-name)
  (loop :for entry :in (alexandria:ensure-list *word-list-vpath*)
        :for directory = (try-vpath-entry entry)
        :thereis (when directory
                   (probe-file (merge-pathnames file-name directory)))))

(defun Word-list (name &key (suffix "txt"))
  (typecase name
    ;; 'FOO -> /some/path/foo.txt
    (symbol (search-word-list-vpath
             (merge-pathnames (string-downcase (symbol-name name))
                              (make-pathname :type suffix))))
    ;; "foo/bar" -> /some/path/foo/bar.txt
    ((or string pathname)
     (search-word-list-vpath
      (merge-pathnames name (make-pathname :type suffix))))))

(defun Pattern (&rest symbols)
  (mapcar (lambda (x) (load-word-list (word-list x)))
          symbols))

;;; Formatting

(defvar *Code-name-formatter* 'default-format-code-name)

(defun Format-code-name (code-name)
  (funcall *code-name-formatter* code-name))

;; Capitalize all words, then concatenate into a single string.
(defun Default-format-code-name (code-name)
  (check-type code-name list)
  (setf code-name (alexandria:mappend
                   (lambda (x)
                     (split-sequence:split-sequence
                      #\Space x :remove-empty-subseqs t))
                   code-name)
        code-name (mapcar 'string-capitalize code-name))
  (format nil "~{~A~^ ~}" code-name))

;;; Code name generation

(defun default-word-pattern ()
  (list (load-word-list (word-list 'adjective))
        (load-word-list (word-list 'noun))))

(defun Generate-basic (&optional (words (default-word-pattern)))
  (assert (consp words))
  (format-code-name
   (loop :for word-list :in words
         :do (assert (consp word-list))
         :collect (alexandria:random-elt word-list))))

(defun Generate-same-first-letter (&optional (words (default-word-pattern))
                                             (tries 10))
  (assert (consp words))
  (when (zerop tries)
    (error "Maximum tries exceeded."))
  (format-code-name
   (loop :for word-list :in words
         ;; Pick a letter from the first word list.
         :for letter = (char-downcase (aref (alexandria:random-elt word-list) 0))
           :then letter
         :for filtered-wordlist = (remove-if-not (lambda (x)
                                                   (eql (char-downcase (aref x 0))
                                                        letter))
                                                 word-list)
         :when (null filtered-wordlist)
           :do (return-from generate-same-first-letter
                 (generate-same-first-letter words (1- tries)))
         :collect (alexandria:random-elt filtered-wordlist))))
