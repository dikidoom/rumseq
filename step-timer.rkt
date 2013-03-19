#lang racket

(provide step-timer%
         seq-timer%)

(require (planet evhan/coremidi)
         (only-in racket/gui/base
                  timer%)
         "models.rkt")

;; a stepping timer that runs itself one
(define step-timer% (class timer%
                      (super-new)
                      (inherit start)
                      ;; replacable notification fn
                      (define notify-fn (lambda () (void)))
                      ;; self-exciting replacer
                      (define/public (tick-with fn time)
                        (set! notify-fn fn)
                        (start (floor time) #t))
                      ;; make callback use custom fn
                      (define/override (notify)
                        (notify-fn))))


;; a stepping timer that is more 
(define seq-timer%
  (class timer%
    (super-new)
    (inherit start)
    ;; ================================ model
    (define midi-connection #f)
    (define sequence '())
    (define index 0)
    ;; ================================ private
    (define (mod-len x)
      (modulo x (length sequence)))

    (define (current-event)
      (list-ref sequence (mod-len index)))

    (define (next-event)
      (list-ref sequence (mod-len (+ index 1))))

    (define (inc-index!)
      (set! index (mod-len (+ index 1))))

    (define (notes->events notes [step 500] [init '()])
      (match notes
        ;; return sorted
        ['() (sort init
                   (lambda (a b)
                     (if (= (event-time a)
                            (event-time b))
                         ;; at same time, note-off takes precedence
                         (if (and (not (note-event-on a))
                                  (note-event-on b))
                             #t
                             #f)
                         ;; else
                         (< (event-time a)
                            (event-time b)))))]
        ;; recurse tail
        [(cons head tail)
         (notes->events tail
                        step
                        (append (list (note-event (* step (note-step head)) ; time
                                                  #t ; on
                                                  (note-value head) ; note
                                                  (note-velocity head)) ; velo
                                      (note-event (+ (* step (note-step head))
                                                     (* step (note-length head))) ; time
                                                  #f ; off
                                                  (note-value head) ; note
                                                  (note-velocity head))) ; velo
                                init))]))

    ;; ================================ main workhorse
    (define/override (notify)
      ;; pick indexed event, run it
      (let ([e (current-event)]
            [next-e (next-event)])
        (when (note-event? e)
          ((if (note-event-on e) note-on note-off)
           midi-connection 1
           (note-event-note e)
           (note-event-velocity e)))
        (inc-index!)
        ;; check time until next event, schedule
        (let ([delta (- (event-time next-e)
                        (event-time e))])
          (if (<= delta 0)
              ;; now
              (notify) ;; (start 0 #t)
              ;; later
              (start (floor delta) #t)))))

    ;; ================================ public
    (define/public (open-midi)
      (set! midi-connection (midi-open)))

    (define/public (close-midi)
      (midi-close midi-connection)
      (set! midi-connection #f))

    (define/public (use-sequence lst)
      (set! sequence lst))

    (define/public (use-notes lst)
      (when (not (empty? lst))
        (set! sequence (notes->events lst))))

    (define/public (run)
      (when (not midi-connection)
        (open-midi))
      (when (not (empty? sequence))
        (start 0 #t)))))
