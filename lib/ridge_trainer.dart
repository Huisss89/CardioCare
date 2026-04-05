import 'dart:math';

import 'calibration_model.dart';

class RidgeTrainer {
  /// Trains multi-output ridge:
  /// X: N x d
  /// Y: N x 2
  /// returns W: (d+1) x 2 (with bias)
  static CalibrationModel fit({
    required List<List<double>> x, // each row [SBP0, DBP0, H, W]
    required List<List<double>> y, // each row [SBP_true, DBP_true]
    double lambda = 5.0,
  }) {
    final n = x.length;
    final d = x[0].length;
    final dp = d + 1; // add bias column

    // Build X' = [X, 1]
    final Xp = List.generate(n, (r) => [...x[r], 1.0]);

    // Compute A = X'^T X' + lambda*I
    final A = List.generate(dp, (_) => List.filled(dp, 0.0));
    for (int i = 0; i < dp; i++) {
      for (int j = 0; j < dp; j++) {
        double sum = 0.0;
        for (int r = 0; r < n; r++) {
          sum += Xp[r][i] * Xp[r][j];
        }
        A[i][j] = sum;
      }
    }
    for (int i = 0; i < dp; i++) {
      A[i][i] += lambda;
    }

    // Compute B = X'^T Y  => dp x 2
    final B = List.generate(dp, (_) => List.filled(2, 0.0));
    for (int i = 0; i < dp; i++) {
      for (int r = 0; r < n; r++) {
        B[i][0] += Xp[r][i] * y[r][0];
        B[i][1] += Xp[r][i] * y[r][1];
      }
    }

    // Solve A * W = B for W (dp x 2)
    final W = _solveTwoRhs(A, B);

    return CalibrationModel(w: W);
  }

  /// Solve A*X=B where B has 2 columns
  static List<List<double>> _solveTwoRhs(
      List<List<double>> A, List<List<double>> B) {
    final dp = A.length;
    // Augment [A | B]
    final M = List.generate(dp, (i) => [...A[i], B[i][0], B[i][1]]);

    // Gaussian elimination with partial pivoting
    for (int col = 0; col < dp; col++) {
      // pivot
      int pivot = col;
      double best = M[col][col].abs();
      for (int r = col + 1; r < dp; r++) {
        final v = M[r][col].abs();
        if (v > best) {
          best = v;
          pivot = r;
        }
      }
      if (best < 1e-12) {
        throw Exception(
            "Matrix is singular or ill-conditioned. Try higher lambda.");
      }
      if (pivot != col) {
        final tmp = M[col];
        M[col] = M[pivot];
        M[pivot] = tmp;
      }

      // normalize row
      final div = M[col][col];
      for (int c = col; c < dp + 2; c++) {
        M[col][c] /= div;
      }

      // eliminate others
      for (int r = 0; r < dp; r++) {
        if (r == col) continue;
        final factor = M[r][col];
        for (int c = col; c < dp + 2; c++) {
          M[r][c] -= factor * M[col][c];
        }
      }
    }

    // Extract W (dp x 2) from augmented matrix
    final W = List.generate(dp, (i) => [M[i][dp], M[i][dp + 1]]);
    return W;
  }
}
