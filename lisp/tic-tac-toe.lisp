; Who wants to run a script and see compiler style notes?
(declaim (sb-ext:muffle-conditions style-warning))

(defpackage :tic-tac-toe
  (:use :cl))

(in-package :tic-tac-toe)

(defconstant +win+ (expt 2 28)
  "A semi-arbitrary numeric value denoting the best outcome.")
(defconstant +lose+ (- (expt 2 28))
  "A semi-arbitrary numeric value denoting the worst outcome.")

(defclass tic-tac-toe ()
  ((score-human :initform 0
                :accessor score-human)
   (score-ai :initform 0
             :accessor score-ai)
   (players :initform '()
            :accessor players)
   (board :initform (make-array '(3 3) :initial-element #\Space
                                :element-type 'standard-char)
          :accessor board)))

(defparameter *game-session* (make-instance 'tic-tac-toe)
  "A global variable holding all our lovely game state.")

(defparameter *win-conditions* '((0 1 2)
                                 (3 4 5)
                                 (6 7 8)
                                 (0 3 6)
                                 (1 4 7)
                                 (2 5 8)
                                 (0 4 8)
                                 (2 4 6))
  "This is an enumeration of all win conditions.
Specifically, A list of lists each specifying a row
of three Xs or Os constituting a win.")

(defun valid-moves (board)
  "Iterate across the board finding all blank spaces
(i.e. valid moves) and returning them as a numbered list of array indices."
  (let ((valid-moves nil)
        (move-count 0))
    ; Note that we could generalize to an N-by-N board by
    ; using a destructuring-bind on the array-dimensions.
    ; See: http://quotenil.com/git/?p=micmac.git;a=summary
    ; especially test/test-game-theory.lisp
    (dotimes (x 3)
      (dotimes (y 3)
        (when (char= #\Space (aref board x y))
          (push (list (incf move-count) x y) valid-moves))))
    valid-moves))

(defun print-board (board &key moves)
  "Print each row of the board inside square brackets.
If MOVES is T, blank spaces (i.e. available moves) will
be numbered starting from 1."
  (let ((move-count 0))
    (flet ((print-row (row-num &key moves)
             (with-output-to-string (result)
               (loop for i in '(0 1 2) do
                    (if (and moves
                             (char= #\Space (aref board row-num i)))
                        (format result " ~A" (incf move-count))
                        (format result " ~A" (aref board row-num i)))))))
      (when moves
        (format t "Your potential moves are:~%"))
      (format t "[~A ]~%[~A ]~%[~A ]~%"
              (print-row 0 :moves moves)
              (print-row 1 :moves moves)
              (print-row 2 :moves moves)))))

(defun print-help ()
  "Display instructions for playing Tic-Tac-Toe."
  (format t "~%Welcome to the glorious world of Tic-Tac-Toe.
If you've never tic'd or tac'd before the rules are simple:
There is a 3 by 3 game board and each player takes turns
filling the 9 empty spaces with their sign, an X or an O.
Whoever gets 3 in a row (vertical, horizontal or diagonal)
first wins! Lectures on Game Trees and Combinatorics
will follow with milk and cookies.~%~%")
  (format t "This is the board with the potential moves numbered...~%")
  (print-board (board *game-session*) :moves t))

(defun make-move (board move letter &key pure)
  "Given a BOARD, MOVE and LETTER, return a BOARD with the specified location
set to LETTER. If PURE is T, ensure that the original board is not modified."
  (if pure
      (let ((arr (make-array '(3 3) :element-type 'standard-char)))
        (loop for i from 0 upto 8 do
             (setf (row-major-aref arr i)
                   (row-major-aref board i)))
        (setf (aref arr (second move) (third move)) letter)
        arr)
      (setf (aref board (second move) (third move)) letter)))

;; Rather than explicitly defining generic functions for all of these,
;; I'll have this handler-bind muffle the compiler notes for clean terminal
;; output. I also violate traditional indentation rules here.
;; The handler-bind form is closed just below the last defmethod.
;;
;; For references, see:
;; http://bugs.launchpad.net/sbcl/+bug/671523 (esp. Attila Lendvai's comment)
;; http://sbcl.sourceforge.net/manual/Controlling-Verbosity.html
(handler-bind ((sb-ext:implicit-generic-function-warning #'muffle-warning))

(defmethod print-score ((game tic-tac-toe))
  "Print the score of the computer and player in GAME."
  (format t "The score is... Scary Robots: ~A   Puny Humans: ~A~%"
          (score-ai game) (score-human game)))

(defmethod reset-board ((game tic-tac-toe))
  "Reset the board for a new game."
  (setf (board game) (make-array '(3 3) :initial-element #\Space
                                 :element-type 'standard-char)))

(defmethod take-turns ((game tic-tac-toe))
  "Ask the player if they would like to go first. Whoever goes first gets
Xs and the other player gets Os. Once a decision is made, loop back and
forth between the competitors until the game is over."
  (let ((human-p (yes-or-no-p "X moves first. Would you like to play X?")))
    (if human-p
        (setf (players game) '(:human :ai))
        (setf (players game) '(:ai :human)))
    (catch 'game-over
      (loop
         (take-turn game #\X human-p) ; X goes first...
         (take-turn game #\O (not human-p))))))

(defmethod take-turn ((game tic-tac-toe) letter human-p)
  "If it is the computer's turn, compute the \"best\" move with SELECT-NEGAMAX,
make the move and inform the user. Otherwise, print the options for the player
and get their selection, then set that location to LETTER. If the game is ended
by this move, display the results of the game and return from TAKE-TURNS."
  (let* ((board (board game))
         (moves (valid-moves board))
         (players (players game)))
    (if human-p
        (let ((limit (length moves))
              (input nil))
          (print-board board :moves t)
          (setf input (get-numeric-input "Please select a move" limit))
          (make-move board (find-if (lambda (x)
                                      (= x input)) moves :key #'car)
                     letter))
        (let ((move (nth-value 1 (select-negamax board letter players
                                                 +lose+ +win+ 1))))
          (format t "Computer moves:~%")
          (make-move board move letter)
          (print-board board)))
    (let ((results (game-over-p (board game) letter players)))
      (when results
        (display-results results game)
        (throw 'game-over nil)))))
) ; Closes the handler-bind muffling implicit-generic warnings...

(defun select-negamax (board letter players alpha beta color)
  "Check to see if the game is over, if so return a value based on who the
winner is. Otherwise, for each valid move for BOARD, run SELECT-NEGAMAX on
a new board where that move has been made, returning both the highest ALPHA
found and the corresponding move."
  ; Largely adapted from http://en.wikipedia.org/wiki/Negamax
  (let* ((opponent (opponent letter))
         (moves (valid-moves board))
         (winner-p (game-over-p board (if (null moves) opponent letter) players))
         (best-move nil))
    (if winner-p
        (setf alpha (* color (board-value winner-p)))
        (dolist (move moves)
          (let* ((board* (make-move board move letter :pure t))
                 (val (- (select-negamax board* opponent players
                                         (- beta) (- alpha) (- color)))))
            (when (> val alpha)
              (setf best-move move
                    alpha val)))))
    (values alpha best-move)))

(defun board-value (winner)
  "Given a WINNER compute the value of the board."
  (ecase winner
    (:draw 0)
    (:ai +win+)
    (:human +lose+)))

(defun get-numeric-input (prompt upper-limit)
  "Get numeric input from the user, reprompting them if they
provide junk input which contains non-numerics or is below 1
or above UPPER-LIMIT."
  (let ((input nil)
        (range-str
         (format nil "You must enter a number between 1 and ~A" upper-limit)))
    (flet ((get-input (message)
             (format t "~A: " message)
             (force-output)
             (setf input (parse-integer (read-line) :junk-allowed t))))
      (get-input prompt)
      (loop until (and input
                       (<= input upper-limit)
                       (> input 0))
         do (get-input range-str))
      input)))

(defun opponent (letter)
  "Return the opponent of LETTER."
  (if (char= #\X letter)
      #\O
      #\X))

(defun game-over-p (board letter players)
  "Check the game BOARD to see if a winner has emerged by
seeing if the board is full and then iterating through the
known *win-conditions*. Return NIL if the game isn't over,
otherwise return the winner. Note that people might expect
a *-p function to return only T or NIL...so don't export it."
  (let ((player (if (char= #\X letter)
                    (first players)
                    (second players))))
    (loop for condition in *win-conditions* do
         (when (three-in-a-row-p letter condition board)
           (return-from game-over-p player)))
    (when (full-board-p board)
      (return-from game-over-p :draw))))

(defun three-in-a-row-p (letter condition board &optional possible-p)
  "Check if LETTER occurs three times in a row on BOARD as specified
by CONDITION or, if POSSIBLE-P is T, whether LETTER is blocked from
achieving the CONDITION. Returns T or NIL."
  (let ((opponent (opponent letter)))
    (if possible-p
        (loop for index in condition
           never (char= opponent (row-major-aref board index)))
        (loop for index in condition
           always (char= letter (row-major-aref board index))))))

(defun full-board-p (board)
  "Check if any blank spaces remain on BOARD.
If so, return NIL, otherwise return T."
  (loop for index from 0 upto 8
        never (char= #\Space (row-major-aref board index))))

(defun display-results (winner game)
  "Increment the score for the winning player or
do nothing in the case of a draw and inform the user
of the game's outcome."
  (ecase winner
    (:human
     (incf (score-human game))
     (format t "The human wins!~%"))
    (:ai
     (incf (score-ai game))
     (format t "The AI wins!~%"))
    (:draw
     (format t "No winner!~%"))))

(defun main ()
  "Print the instructions for playing Tic-Tac-Toe.
Afterwards, continually prompt the player to play and
start a new game each time they respond affirmatively."
  (print-help)
  (flet ((new-game? ()
           (reset-board *game-session*)
           (yes-or-no-p "Would you like to play Tic-Tac-Toe?")))
    (loop until (not (new-game?)) do
         (take-turns *game-session*)
         (print-score *game-session*)))
  (format t "~%Thanks for playing!~%~%")
  (sb-ext:quit))

(defun the-kris-bugs ()
  (let ((arr #2A((#\Space #\X #\X) (#\X #\O #\O) (#\Space #\O #\X)))
        (players '(:human :ai)))
    (multiple-value-bind (value move)
        (select-negamax arr #\O players +lose+ +win+ 1)
      (format t "Value: ~A~%Move: ~A~%" value move)
      (make-move arr '(2 2 0) #\O)
      (make-move arr '(1 0 0) #\X)
      (format t "The Kris Bugs:~%Right Move? ~A~%Right Winner? ~A~%"
              (equal '(1 0 0) move)
              (eql  (game-over-p arr #\X players) :human))
      (print-board arr))))

;(trace select-negamax game-over-p)

(main)
;(the-kris-bugs)
