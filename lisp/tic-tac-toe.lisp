; Who wants to run a script and see compiler style notes?
(declaim (sb-ext:muffle-conditions style-warning))

(defpackage :tic-tac-toe
  (:use :cl))

(in-package :tic-tac-toe)

(defclass tic-tac-toe ()
  ((score-human :initform 0
                :accessor score-human)
   (score-ai :initform 0
             :accessor score-ai)
   (board :initform (make-array '(3 3) :initial-element " ")
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

;; Rather than explicitly defining generic functions for all of these,
;; I'll have this handler-bind muffle the compiler notes for clean terminal
;; output. I also violate traditional indentation rules here.
;; The handler-bind form is closed just below the last defmethod.
;;
;; For references, see:
;; http://bugs.launchpad.net/sbcl/+bug/671523 (esp. Attila Lendvai's comment)
;; http://sbcl.sourceforge.net/manual/Controlling-Verbosity.html
(handler-bind ((sb-ext:implicit-generic-function-warning #'muffle-warning))

(defmethod print-board ((game tic-tac-toe) &key moves)
  "Print each row of the board inside square brackets.
If MOVES is T, blank spaces (i.e. available moves) will
be numbered starting from 1 and we also return a list of
valid moves, each of which is itself a list containing
the number denoting that move and its respective array indices."
  (let ((move-count 0)
        (board (board game))
        (valid-moves nil))
    (flet ((print-row (row-num &key moves)
             (with-output-to-string (result)
               (loop for i in '(0 1 2) do
                    (if (and moves
                             (string= (aref board row-num i) " "))
                        (progn
                          (format result " ~A" (incf move-count))
                          (push (list move-count row-num i) valid-moves))
                        (format result " ~A" (aref board row-num i)))))))
      (when moves
        (format t "Your potential moves are:~%"))
      (format t "[~A ]~%[~A ]~%[~A ]~%"
              (print-row 0 :moves moves)
              (print-row 1 :moves moves)
              (print-row 2 :moves moves))
      valid-moves)))

(defmethod print-score ((game tic-tac-toe))
  "Print the score of the computer and player in GAME."
  (format t "The score is... Scary Robots: ~A   Puny Humans: ~A~%"
          (score-ai game) (score-human game)))

(defmethod reset-board ((game tic-tac-toe))
  "Reset the board for a new game."
  (setf (board game) (make-array '(3 3) :initial-element " ")))

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
  (print-board *game-session* :moves t))

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

(defmethod take-turns ((game tic-tac-toe))
  "Ask the player if they would like to go first. Whoever goes first gets
Xs and the other player gets Os. Once a decision is made, loop back and
forth between the competitors until the game is over."
  (let ((human-p (yes-or-no-p "X moves first. Would you like to play X?")))
    (catch 'game-over
      (loop
         (take-turn game "X" human-p) ; X goes first...
         (take-turn game "O" (not human-p))))))

(defmethod take-turn ((game tic-tac-toe) letter human-p)
  "If it's the computers turn, TODO.
Otherwise, print the options for the player and get
their selection, then set that location to LETTER.
Finally, if the game is ended by this move, return from
TAKE-TURNS."
  (if human-p
      (let* ((valid-moves (print-board game :moves t))
             (limit (length valid-moves))
             (choice (get-numeric-input "Please select a move" limit))
             (move (find-if (lambda (num) (= num choice))
                            valid-moves :key #'car))
             (row (second move))
             (column (third move)))
        (setf (aref (board game) row column) letter))
      (format t "TODO: Computer moves...~%"))
  (when (game-over-p game letter human-p)
    (throw 'game-over nil)))

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
      (if (and input
               (<= input upper-limit)
               (> input 0))
          input
          (get-input range-str)))))

(defmethod game-over-p ((game tic-tac-toe) letter human-p)
  "Check the game board to see if a winner has emerged by seeing
if the board is full and then iterating through the known
*win-conditions*. Return nil if the game isn't over,
otherwise change the score appropriately and inform the user."
  (let ((board (board game))
        (player (if human-p :human :ai)))
    (when (full-board-p board)
      (display-results :draw game)
      (return-from game-over-p t))
    (loop for condition in *win-conditions* do
         (when (three-in-a-row letter condition board)
           (display-results player game)
           (return-from game-over-p t)))))
) ; Closes the handler-bind muffling implicit-generic warnings...

(defun three-in-a-row (letter condition board)
  "Check if LETTER occurs three times in a row
on BOARD as specified by CONDITION. Returns T or NIL."
  (loop for index in condition
        always (string= letter (row-major-aref board index))))

(defun full-board-p (board)
  "Check if any blank spaces remain on BOARD.
If so, return NIL, otherwise return T."
  (loop for index from 0 upto 8
        never (string= " " (row-major-aref board index))))

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

;(main)
