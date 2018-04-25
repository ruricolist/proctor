(in-package #:proctor)

(defun run (test)
  (~> test
      get-test-result
      print-test-result))

(defun failure-data (test)
  (~> test
      get-test-result
      extract-failure-data))

(defmacro runq (test)
  `(run ',test))

(defvar *debug-test* nil)

(defun debug-test (test)
  (let ((*debug-test* t))
    (run (find-test test))))

(defmacro def-test (test-name (&key suite) &body body)
  (let ((file (test-result-file test-name))
        (suite (or suite (test-name (current-suite)))))
    `(progn
       (save-test ',test-name
                  (lambda ()
                    (overlord:with-script ()
                      ,@body))
                  :in ',suite)
       (overlord:file-target ,test-name ,file ()
         ;; Include the body literally so changes are detected.
         ',body
         (depend-on-suite-parents ',suite)
         (depend-on-suite-deps ',suite)
         (run-test-to-file ',test-name ,file))
       ',test-name)))

(defmacro test (name &body body)
  (let ((opts (rest (ensure-list name))))
    `(def-test ,name ,opts
       ,@body)))

(defmacro def-suite (name &body body)
  (nest
   (multiple-value-bind (opts dependencies)
       (parse-leading-keywords body))
   (destructuring-bind (&key in description) opts)
   (let ((file (test-result-file name))
         (all-deps
           (append
            (suite-parent-deps name)
            dependencies))))
   `(progn
      (save-suite ',name
                  :in ',in
                  :description ',description
                  :deps-fn (lambda ()
                             (overlord:with-script ()
                               ,@all-deps)))
      ;; The file that holds the suite results.
      (overlord:file-target ,name ,file ()
        (run-suite-to-file ',name ,file))
      ;; The file that holds the suite's parent chain.
      (overlord:file-target
          ,(symbolicate name '.parents)
          ,(suite-parents-file name)
          ()
        (maybe-save-parents-file ',name))
      ;; A configuration that holds the dependencies.
      (overlord:defconfig ,(suite-deps-config name)
          ',all-deps)
      ',name)))

(defmacro in-suite (name)
  `(eval-always
     (setf (current-suite) ',name)))

(defmacro is (test &rest reason-args)
  (declare (ignore reason-args))
  `(is* (test-form ,test)))

(defmacro is-true (test &rest reason-args)
  (declare (ignore reason-args))
  `(is (true ,test)))

(defmacro is-false (test &rest reason-args)
  (declare (ignore reason-args))
  `(is (not ,test)))

(defmacro signals (condition-name &body body)
  `(signals*
    ',condition-name
    (test-form
      ,@body)))

(defmacro finishes (&body body)
  `(finishes*
    (test-form
      ,@body)))
