#lang racket
(require (planet dyoo/while-loop:1:=1)
         "etc.rkt"
         "read.rkt"
         memoize)

(provide format-module)

(define (abbrev-prefix v)
 (match v
  ((list (== quasiquote-symbol) _)
   "`")
  ((list (== quasisyntax-symbol) _)
   "#`")
  ((list (== quote-symbol) _)
   "'")
  ((list (== syntax-symbol) _)
   "#'")
  ((list (== unquote-splicing-symbol) _)
   ",@")
  ((list (== unquote-symbol) _)
   ",")
  ((list (== unsyntax-splicing-symbol) _)
   "#,@")
  ((list (== unsyntax-symbol) _)
   "#,")
  (_ #f)))

(define (blank-after-decls lst)
 (match lst
  ((list a (== blank-symbol) b ...)
   (list* a blank-symbol (blank-after-decls b)))
  ((list (? decl*? a) b c ...)
   (list* a blank-symbol (blank-after-decls (cons b c))))
  ((list a b ...)
   (cons a (blank-after-decls b)))
  (_ '())))

(define (blank-before-comments lst)
 (match lst
  ((list (== blank-symbol) a ...)
   (cons blank-symbol (blank-before-comments a)))
  ((list (list (== line-comment-symbol) a) b ...)
   (list* (list line-comment-symbol a) (blank-before-comments b)))
  ((list a (list (== line-comment-symbol) b) c ...)
   (list* a blank-symbol (list line-comment-symbol b) (blank-before-comments c)))
  ((list a b ...)
   (cons a (blank-before-comments b)))
  (_ '())))

(define (decl*? x)
 (match x
  ((list (or 'provide
             'require)
         b ...)
   #t)
  (_ (decl? x))))

(define (expr col v)
 (define col1 (+ col 1))
 (define col2
  (when (pair? v)
   (+ col 2 (width (car v)))))
 (define op
  (when (pair? v)
   (~a (car v))))
 (define op2
  (when (pair? v)
   (format "(~a "
    (car v))))
 (match v
  ; atom
  ((== blank-symbol)
   "")
  ((? atom? _)
   (~s v))

  ; comment
  ((list (== block-comment-symbol) s)
   s)
  ((list (== expr-comment-symbol) a)
   (string-append "#;" (expr (+ col 2) a)))
  ((list (== line-comment-symbol) s)
   s)

  ; abbrev prefix
  ((? abbrev-prefix (list _ w))
   (define s (abbrev-prefix v))
   (string-append s (expr (+ col (string-length s)) w)))

  ; special form
  ((list (or 'define
             'set!)
         a
         b)
   #:when
   (and (symbol? a)
        (inline col1 v))
   (string-append "(" (inline col1 v) ")"))
  ((list (or 'begin
             'cond
             'else)
         b ...)
   (string-append "(" op "\n" (make-string col1 #\space) (exprs col1 b) ")"))
  ((list (or 'case
             'define
             'define-syntax
             'define/memo
             'define/memo*
             'eprintf
             'for
             'for*
             'for*/and
             'for*/first
             'for*/hash
             'for*/hasheq
             'for*/hasheqv
             'for*/last
             'for*/list
             'for*/or
             'for*/product
             'for*/sum
             'for/and
             'for/first
             'for/hash
             'for/hasheq
             'for/hasheqv
             'for/last
             'for/list
             'for/or
             'for/product
             'for/sublists
             'for/sum
             'format
             'if
             'lambda
             'lambda/memo
             'lambda/memo*
             'match
             'parameterize
             'printf
             'receive
             'syntax-rules
             'unless
             'when
             'while
             'while/list
             'with-handlers
             'with-output-to-file)
         a
         b ...)
   (string-append op2
                  (expr col2 a)
                  "\n"
                  (make-string col1 #\space)
                  (exprs col1 b)
                  ")"))
  ((list 'let (list a ...) b ...)
   (string-append op2
                  (expr col2 a)
                  "\n"
                  (make-string col1 #\space)
                  (exprs col1 b)
                  ")"))
  ((list (or 'let
             'syntax-case)
         id
         (list a ...)
         b ...)
   (string-append op2
                  (~a id)
                  " ("
                  (exprs (+ col2 (width id) 2) a)
                  ")\n"
                  (make-string col1 #\space)
                  " "
                  (exprs col1 b)
                  ")"))

  ; no args
  ((list f)
   (string-append "(" (expr col1 f) ")"))

  ; args inline
  ((list (not (or 'and
                  'or
                  'provide
                  'require))
         a ...)
   #:when
   (and (symbol? (car v))
        (not (memq line-comment-symbol (flatten v)))
        (inline col1 v))
   (string-append "(" (inline col1 v) ")"))

  ; args aligned
  ((list (? symbol? f) a ...)
   #:when
   (for/and ((w a))
    (< (+ col2 (width w)) 80))
   (string-append op2 (exprs col2 a) ")"))

  ; args unaligned
  ((list f a ...)
   (string-append "("
                  (expr col1 f)
                  "\n"
                  (make-string col1 #\space)
                  (exprs col1 a)
                  ")"))))

(define (exprs col lst)
 (set! lst (blank-after-decls lst))
 (set! lst (blank-before-comments lst))
 (set! lst
       (let loop ((lst lst))
         (match lst
         ((list a '... c ...)
          (cons (string-append (expr col a) " ...") (loop c)))
         ((list a b ...)
          (cons (expr col a) (loop b)))
         (_ '()))))
 (string-join lst (string-append "\n" (make-string col #\space))))

(define (format-module m)
 (trim-lines (exprs 0 m)))

(define (inline col lst)
 (set! lst
       (let loop ((col col)
                  (lst lst))
         (match lst
         ((list a b ...)
          (cons (expr col a) (loop (+ col (width a) 1) b)))
         (_ '()))))
 (define s (string-join lst " "))
 (and (not (string-contains? s "\n"))
      (< (+ col (string-length s)) 80)
      s))

(define (max-line-length s)
 (define lines (string-split s "\n"))
 (if (null? lines)
  0
  (apply max (map string-length lines))))

(define (trim-lines s)
 (define lines (string-split s "\n"))
 (set! lines
       (for/list ((line lines))
        (string-trim line #:left? #f)))
 (string-join lines "\n" #:after-last "\n"))

(define/memo* (width v)
 (max-line-length (expr 0 v)))

(define blank-symbol (gensym))