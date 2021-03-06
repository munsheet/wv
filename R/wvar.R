# Copyright (C) 2017 James Balamuta, Justin Lee, Stephane Guerrier, Roberto Molinari
#
# This file is part of wv R Methods Package
#
# The `wv` R package is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# The `wv` R package is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

#' @title Wavelet Variance
#' 
#' @description
#' Calculates the (MO)DWT wavelet variance
#' @param x         A \code{vector} with dimensions N x 1. 
#' @param decomp    A \code{string} that indicates whether to use the "dwt" or "modwt" decomposition.
#' @param filter    A \code{string} that specifies what wavelet filter to use. 
#' @param nlevels   An \code{integer} that indicates the level of decomposition. It must be less than or equal to floor(log2(length(x))).
#' @param robust    A \code{boolean} that triggers the use of the robust estimate.
#' @param eff       A \code{double} that indicates the efficiency as it relates to an MLE.
#' @param alpha     A \code{double} that indicates the \eqn{\left(1-p\right)*\alpha}{(1-p)*alpha} confidence level 
#' @param freq      A \code{numeric} that provides the rate of samples.
#' @param from.unit A \code{string} indicating the unit which the data is converted from.
#' @param to.unit   A \code{string} indicating the unit which the data is converted to.
#' @param ... Further arguments passed to or from other methods.
#' @return A \code{list} with the structure:
#' \describe{
#'   \item{"variance"}{Wavelet Variance}
#'   \item{"ci_low"}{Lower CI}
#'   \item{"ci_high"}{Upper CI}
#'   \item{"robust"}{Robust active}
#'   \item{"eff"}{Efficiency level for Robust}
#'   \item{"alpha"}{p value used for CI}
#'   \item{"unit"}{String representation of the unit}
#' }
#' @details 
#' If \code{nlevels} is not specified, it is set to \eqn{\left\lfloor {{{\log }_2}\left( {length\left( x \right)} \right)} \right\rfloor}{floor(log2(length(x)))}
#' @author James Balamuta and Justin Lee
#' @rdname wvar
#' @examples
#' set.seed(999)
#' x = rnorm(100)
#' # Default
#' wvar(x)
#' 
#' # Robust
#' wvar(x, robust = TRUE, eff=0.3)
#' 
#' # Classical
#' wvar(x, robust = FALSE, eff=0.3)
#' 
#' # 90% Confidence Interval 
#' wvar(x, alpha = 0.10)
#' @export
wvar = function(x, ...) {
  UseMethod("wvar")
}

#' @rdname wvar
#' @export
wvar.lts = function(x, decomp = "modwt", filter = "haar", nlevels = NULL, alpha = 0.05, robust = FALSE, eff = 0.6, to.unit = NULL, ...){
  warning('`lts` object is detected. This function can only operate on the combined process.')
  freq = attr(x, 'freq')
  unit = attr(x, 'unit')
  x = x[,ncol(x)]
  
  wvar.default(x, decomp, filter, nlevels, alpha, robust, eff, freq = freq, from.unit = unit, to.unit = to.unit)
}

#' @rdname wvar
#' @export
wvar.gts = function(x, decomp="modwt", filter = "haar", nlevels = NULL, alpha = 0.05, robust = FALSE, eff = 0.6, to.unit = NULL, ...){
  freq = attr(x, 'freq')
  unit = attr(x, 'unit')
  x = x[,1]
  
  wvar.default(x, decomp, filter, nlevels, alpha, robust, eff, freq = freq, from.unit = unit, to.unit = to.unit)
}

#' @rdname wvar
#' @export
wvar.ts = function(x, decomp="modwt", filter = "haar", nlevels = NULL, alpha = 0.05, robust = FALSE, eff = 0.6, to.unit = NULL, ...){
  freq = attr(x, 'tsp')[3]
  unit = NULL
  
  wvar.default(x, decomp, filter, nlevels, alpha, robust, eff, freq = freq, from.unit = unit, to.unit = to.unit)
}

#' @rdname wvar
#' @export
wvar.default = function(x, decomp = "modwt", filter = "haar", nlevels = NULL, alpha = 0.05, robust = FALSE, eff = 0.6, freq = 1, from.unit = NULL, to.unit = NULL, ...){
  if(is.null(x)){
    stop("`x` must contain a value")
  }else if((is.data.frame(x) || is.matrix(x))){
    if(ncol(x) > 1) stop("There must be only one column of data supplied.")
  }
  
  if(is.null(nlevels)){
    nlevels = floor(log2(length(x)))
  }

  # check freq
  if(!is(freq,"numeric") || length(freq) != 1){ stop("'freq' must be one numeric number.") }
  if(freq <= 0) { stop("'freq' must be larger than 0.") }
  
  # check unit
  all.units = c('ns', 'ms', 'sec', 'second', 'min', 'minute', 'hour', 'day', 'mon', 'month', 'year')
  if( (!is.null(from.unit) && !from.unit %in% all.units) || (!is.null(to.unit) && !to.unit %in% all.units) ){
      stop('The supported units are "ns", "ms", "sec", "min", "hour", "day", "month", "year". ')
  }
  
  if(robust) {
    if(eff > 0.99) {
      stop("The efficiency specified is too close to the classical case. Use `robust = FALSE`")
    }
  }
  
  obj =  .Call('wv_modwt_wvar_cpp', PACKAGE = 'wv',
               signal=x, nlevels=nlevels, robust=robust, eff=eff, alpha=alpha, 
               ci_type="eta3", strWavelet=filter, decomp = decomp)
  
  # nlevels may be changed during modwt
  nlevels = nrow(obj)
  
  scales = .Call('wv_scales_cpp', PACKAGE = 'wv', nlevels)/freq
  
  # NO unit conversion
  if( is.null(from.unit) && is.null(to.unit)==F ){
    warning("'from.unit' is NULL. Unit conversion was not done.")
  }
  
  # unit conversion
  if (!is.null(from.unit)){
    if (!is.null(to.unit)){
      convert.obj = unitConversion(scales, from.unit = from.unit, to.unit = to.unit)
      
      if (convert.obj$converted) {
        # YES unit conversion
        scales = convert.obj$x
        message(paste0('Unit of object is converted from ', from.unit, ' to ', to.unit), appendLF = T)
      }
    }
  }
  
  if(!is.null(from.unit) && !is.null(to.unit)){ 
    unit = to.unit
  }else{
    unit = from.unit}
  
  create_wvar(obj, decomp, filter, robust, eff, alpha, scales, unit)
}

#' @title Create a \code{wvar} object
#' 
#' @description
#' Structures elements into a \code{wvar} object
#' @param obj    A \code{matrix} with dimensions N x 3, that contains the wavelet variance, low ci, hi ci.
#' @param decomp A \code{string} that indicates whether to use the "dwt" or "modwt" decomposition.
#' @param filter A \code{string} that specifies the type of wavelet filter used in the decomposition.
#' @param robust A \code{boolean} that triggers the use of the robust estimate.
#' @param eff    A \code{double} that indicates the efficiency as it relates to an MLE.
#' @param alpha  A \code{double} that indicates the \eqn{\left(1-p\right)*\alpha}{(1-p)*alpha} confidence level.
#' @param scales A \code{vec} that contains the amount of decomposition done at each level.
#' @param unit   A \code{string} that contains the unit expression of the frequency.
#' @return A \code{list} with the structure:
#' \describe{
#'   \item{"variance"}{Wavelet Variance}
#'   \item{"ci_low"}{Lower CI}
#'   \item{"ci_high"}{Upper CI}
#'   \item{"robust"}{Robust active}
#'   \item{"eff"}{Efficiency level for Robust}
#'   \item{"alpha"}{p value used for CI}
#'   \item{"unit"}{String representation of the unit}
#' }
#' @keywords internal
create_wvar = function(obj, decomp, filter, robust, eff, alpha, scales, unit){
  structure(list(variance = obj[,1],
                       ci_low = obj[,2], 
                       ci_high = obj[,3], 
                       robust = robust, 
                       eff = eff,
                       alpha = alpha,
                       scales = scales,
                       decomp = decomp,
                       unit = unit,
                       filter = filter), class = "wvar")
}

#' @title Print Wavelet Variances
#' 
#' @description
#' Displays the summary table of wavelet variance.
#' @author James Balamuta 
#' @method print wvar
#' @export
#' @keywords internal
#' @param x A \code{wvar} object.
#' @param ... further arguments passed to or from other methods.
#' @return Summary table
#' @examples
#' set.seed(999)
#' x = rnorm(100)
#' out = wvar(x)
#' print( out )
print.wvar = function(x, ...){
  mat = matrix(unlist(x[1:3]),ncol=3,byrow=F)
  colnames(mat) = c("Variance", "Low CI", "High CI")
  rownames(mat) = x$scales
  print(mat)
}

#' @title Summary of Wavelet Variances
#' 
#' @description 
#' Displays the summary table of wavelet variance accounting for CI values and supplied efficiency.
#' @method summary wvar
#' @export
#' @keywords internal
#' @param object A \code{wvar} object.
#' @return Summary table and other properties of the object.
#' @param ... additional arguments affecting the summary produced.
#' @author James Balamuta
#' @examples
#' set.seed(999)
#' x = rnorm(100)
#' ret = wvar(x)
#' summary(ret)
summary.wvar = function(object, ...){
  name = if(object$robust){
    "robust" 
  }else{
    "classical"
  }
  cat("Results of the wavelet variance calculation using the ",name, " method.\n",sep="")
  if(object$robust){
    cat("Robust was created using efficiency=",object$eff,"\n",sep="")
  }
  
  cat("The confidence interval was generated using (1-",object$alpha,")*100 \n",sep="")
  
  print(object)
}

#' @title Plot Wavelet Variances
#' 
#' @description 
#' Displays a plot of wavelet variance accounting for CI values and supplied efficiency.
#' @method plot wvar
#' @export
#' @keywords internal
#' @param x                A \code{wvar} object.
#' @param units            A \code{string} that specifies the units of time plotted on the x axis.
#' @param xlab             A \code{string} that gives a title for the x axis.
#' @param ylab             A \code{string} that gives a title for the y axis.
#' @param main             A \code{string} that gives an overall title for the plot.
#' @param col_wv           A \code{string} that specifies the color of the wavelet variance line.
#' @param col_ci           A \code{string} that specifies the color of the confidence interval polygon.
#' @param nb_ticks_x       An \code{integer} that specifies the maximum number of ticks for the x-axis.
#' @param nb_ticks_y       An \code{integer} that specifies the maximum number of ticks for the y-axis.
#' @param legend_position  A \code{string} that specifies the position of the legend (use \code{legend_position = NA} to remove legend).
#' @param ci_wv            A \code{double} that specifies the confidence interval to be used in the WV calculation.
#' @param point_pch        A \code{double} that specifies the symbol type to be plotted.
#' @param point_cex        A \code{double} that specifies the size of each symbol to be plotted.
#' @param ... Additional arguments affecting the plot.
#' @return Plot of wavelet variance and confidence interval for each scale.
#' @author Stephane Guerrier, Nathanael Claussen, and Justin Lee
#' @examples 
#' set.seed(999)
#' n = 10^4
#' Xt = rnorm(n)
#' wv = wvar(Xt)
#' plot(wv)
#' plot(wv, main = "Simulated white noise", xlab = "Scales")
#' plot(wv, units = "sec", legend_position = "topright")
#' plot(wv, col_wv = "darkred", col_ci = "pink")
plot.wvar = function(x, units = NULL, xlab = NULL, ylab = NULL, main = NULL, 
                     col_wv = NULL, col_ci = NULL, nb_ticks_x = NULL, nb_ticks_y = NULL,
                     legend_position = NULL, ci_wv = NULL, point_cex = NULL, 
                     point_pch = NULL, ...){
  
  # Labels
  if (is.null(xlab)){
    if (is.null(units)){
      xlab = expression(paste("Scale ", tau, sep =""))
    }else{
      xlab = bquote(paste("Scale ", tau, " [", .(units), "]", sep = " "))
    }
  }
  
  if (is.null(ylab)){
    if(is.null(units)){
      ylab = expression(paste("Wavelet Variance ", nu^2, sep = ""))
    }else{
      ylab = bquote(paste("Wavelet Variance ", nu^2, " [", .(units)^2, "]", sep = " "))
    }
  }
  
  # Main Title
  if (is.null(main)){
    main = "Haar Wavelet Variance Representation"
  }
  
  # Line and CI colors
  if (is.null(col_wv)){
    col_wv = "darkblue"
  }
  
  if (is.null(col_ci)){
    col_ci = hcl(h = 210, l = 65, c = 100, alpha = 0.2)
  }
  
  # Range
  x_range = range(x$scales)
  x_low = floor(log2(x_range[1]))
  x_high = ceiling(log2(x_range[2]))
  
  y_range = range(c(x$ci_low, x$ci_high))
  y_low = floor(log2(y_range[1]))
  y_high = ceiling(log2(y_range[2]))
  
  # Axes
  if (is.null(nb_ticks_x)){
    nb_ticks_x = 6
  }
  
  if (is.null(nb_ticks_y)){
    nb_ticks_y = 5
  }
  
  x_ticks = seq(x_low, x_high, by = 1)
  if (length(x_ticks) > nb_ticks_x){
    x_ticks = x_low + ceiling((x_high - x_low)/(nb_ticks_x + 1))*(0:nb_ticks_x)
  }
  x_labels = sapply(x_ticks, function(i) as.expression(bquote(10^ .(i))))
  
  y_ticks <- seq(y_low, y_high, by = 1)
  if (length(y_ticks) > nb_ticks_y){
    y_ticks = y_low + ceiling((y_high - y_low)/(nb_ticks_y + 1))*(0:nb_ticks_y)
  }
  y_labels <- sapply(y_ticks, function(i) as.expression(bquote(10^ .(i))))
  
  # Legend position
  if (is.null(legend_position)){
    if (which.min(abs(c(y_low, y_high) - log2(x$variance[1]))) == 1){
      legend_position = "topleft"
    }else{
      legend_position = "bottomleft"
    }
  }   
  
  # Main plot                     
  plot(NA, xlim = x_range, ylim = y_range, xlab = xlab, ylab = ylab, 
       log = "xy", xaxt = 'n', yaxt = 'n', bty = "n", ann = FALSE)
  win_dim = par("usr")
  
  par(new = TRUE)
  plot(NA, xlim = x_range, ylim = 10^c(win_dim[3], win_dim[4] + 0.09*(win_dim[4] - win_dim[3])),
       xlab = xlab, ylab = ylab, log = "xy", xaxt = 'n', yaxt = 'n', bty = "n")
  win_dim = par("usr")
  
  # Add grid
  abline(v = 2^x_ticks, lty = 1, col = "grey95")
  abline(h = 2^y_ticks, lty = 1, col = "grey95")
  
  # Add title
  x_vec = 10^c(win_dim[1], win_dim[2], win_dim[2], win_dim[1])
  y_vec = 10^c(win_dim[4], win_dim[4],
               win_dim[4] - 0.09*(win_dim[4] - win_dim[3]), 
               win_dim[4] - 0.09*(win_dim[4] - win_dim[3]))
  polygon(x_vec, y_vec, col = "grey95", border = NA)
  text(x = 10^mean(c(win_dim[1], win_dim[2])), y = 10^(win_dim[4] - 0.09/2*(win_dim[4] - win_dim[3])), main)
  
  # Add axes and box
  lines(x_vec[1:2], rep(10^(win_dim[4] - 0.09*(win_dim[4] - win_dim[3])),2), col = 1)
  y_ticks = y_ticks[(2^y_ticks) < 10^(win_dim[4] - 0.09*(win_dim[4] - win_dim[3]))]
  y_labels = y_labels[1:length(y_ticks)]
  box()
  axis(1, at = 2^x_ticks, labels = x_labels, padj = 0.3)
  axis(2, at = 2^y_ticks, labels = y_labels, padj = -0.2)  
  
  # CI for the WV
  if (ci_wv == TRUE || is.null(ci_wv)){
    polygon(c(x$scales, rev(x$scales)), c(x$ci_low, rev(x$ci_high)),
            border = NA, col = col_ci)
  }
  
  # Add legend
  CI_conf = 1 - x$alpha
  
  if (x$robust == TRUE){
    wv_title_part1 = "Empirical Robust WV "
  }else{
    wv_title_part1 = "Empirical WV "
  }
  
  if (!is.na(legend_position)){
    if (legend_position == "topleft"){
      legend_position = 10^c(1.1*win_dim[1], 0.98*(win_dim[4] - 0.09*(win_dim[4] - win_dim[3])))
      legend(x = legend_position[1], y = legend_position[2],
             legend = c(as.expression(bquote(paste(.(wv_title_part1), hat(nu)^2))),
                        as.expression(bquote(paste("CI(",hat(nu)^2,", ",.(CI_conf),")")))),
             pch = c(16, 15), lty = c(1, NA), col = c(col_wv, col_ci), cex = 1, pt.cex = c(1.25, 3), bty = "n")
    }else{
      if (legend_position == "topright"){
        legend_position = 10^c(0.7*win_dim[2], 0.98*(win_dim[4] - 0.09*(win_dim[4] - win_dim[3])))
        legend(x = legend_position[1], y = legend_position[2],
               legend = c(as.expression(bquote(paste(.(wv_title_part1), hat(nu)^2))), 
                          as.expression(bquote(paste("CI(",hat(nu)^2,", ",.(CI_conf),")")))),
               pch = c(16, 15), lty = c(1, NA), col = c(col_wv, col_ci), cex = 1, pt.cex = c(1.25, 3), bty = "n")
      }else{
        legend(legend_position,
               legend = c(as.expression(bquote(paste(.(wv_title_part1), hat(nu)^2))), 
                          as.expression(bquote(paste("CI(",hat(nu)^2,", ",.(CI_conf),")")))),
               pch = c(16, 15), lty = c(1, NA), col = c(col_wv, col_ci), cex = 1, pt.cex = c(1.25, 3), bty = "n")
      }
    }
  }
  
  # Add WV
  lines(x$scales, x$variance, type = "l", col = col_wv, pch = 16)
  
  if (is.null(point_pch)){
    point_pch = 16
  }
  
  if (is.null(point_cex)){
    point_cex = 1.25
  }
  lines(x$scales, x$variance, type = "p", col = col_wv, pch = point_pch, cex = point_cex)
}


#' @title Comparison between classical and robust Wavelet Variances
#' 
#' @description 
#' Displays a plot of the wavelet variances (classical and robust) for a given time series accounting for CI values.
#' @param x A time series object.
#' @param eff             An \code{integer} that specifies the efficiency of the robust estimator.
#' @param units           A \code{string} that specifies the units of time plotted on the x axis.
#' @param xlab            A \code{string} that gives a title for the x axis.
#' @param ylab            A \code{string} that gives a title for the y axis.
#' @param main            A \code{string} that gives an overall title for the plot.
#' @param col_wv          A \code{string} that specifies the color of the wavelet variance line.
#' @param col_ci          A \code{string} that specifies the color of the confidence interval shade.
#' @param nb_ticks_x      An \code{integer} that specifies the maximum number of ticks for the x-axis.
#' @param nb_ticks_y      An \code{integer} that specifies the maximum number of ticks for the y-axis.
#' @param legend_position A \code{string} that specifies the position of the legend (use \code{legend_position = NA} to remove legend).
#' @param ... Additional arguments affecting the plot.
#' @return Plot of wavelet variance and confidence interval for each scale.
#' @author Stephane Guerrier, Nathanael Claussen, and Justin Lee
#' @examples 
#' set.seed(999)
#' n = 10^4
#' Xt = rnorm(n)
#' wv = wvar(Xt)
#' plot(wv)
#' plot(wv, main = "Simulated white noise", xlab = "Scales")
#' plot(wv, units = "sec", legend_position = "topright")
#' plot(wv, col_wv = "darkred", col_ci = "pink")
#' @export
robust_eda = function(x, eff = 0.6, units = NULL, xlab = NULL, ylab = NULL, main = NULL, 
                      col_wv = NULL, col_ci = NULL, nb_ticks_x = NULL, nb_ticks_y = NULL,
                      legend_position = NULL, ...){
  wv_cl  = wvar(x)
  wv_rob = wvar(x, robust = TRUE, eff = eff)
  
  # Labels
  if (is.null(xlab)){
    if (is.null(units)){
      xlab = expression(paste("Scale ", tau, sep =""))
    }else{
      xlab = bquote(paste("Scale ", "", tau, " [", .(units), "]", sep = ""))
    }
  }
  
  if (is.null(ylab)){
    if(is.null(units)){
      ylab = expression(paste("Wavelet Variance ", "", (nu^2), "", sep = ""))
    }else{
      ylab = bquote(paste("Wavelet Variance ", "", (nu^2), " [", .(units)^2, "]", sep = ""))
    }
  }
  
  # Main Title
  if (is.null(main)){
    main = "Classical vs Robust WV"
  }
  
  # Line and CI colors
  if (is.null(col_wv)){
    col_wv = rep(NA, 2)
    col_wv[1] = "darkblue"
    col_wv[2] = "darkorange2"
  }
  
  if (is.null(col_ci)){
    col_ci = rep(NA, 2)
    col_ci[1] = hcl(h = 210, l = 65, c = 100, alpha = 0.2)
    col_ci[2] = hcl(h = 60, l = 65, c = 100, alpha = 0.2)
  }
  
  # Range
  x_range = range(wv_cl$scales)
  x_low = floor(log2(x_range[1]))
  x_high = ceiling(log2(x_range[2]))
  
  y_range = range(c(wv_cl$ci_low, wv_cl$ci_high, wv_rob$ci_low, wv_rob$ci_high))
  y_low = floor(log2(y_range[1]))
  y_high = ceiling(log2(y_range[2]))
  
  # Axes
  if (is.null(nb_ticks_x)){
    nb_ticks_x = 6
  }
  
  if (is.null(nb_ticks_y)){
    nb_ticks_y = 5
  }
  
  x_ticks = seq(x_low, x_high, by = 1)
  if (length(x_ticks) > nb_ticks_x){
    x_ticks = x_low + ceiling((x_high - x_low)/(nb_ticks_x + 1))*(0:nb_ticks_x)
  }
  x_labels = sapply(x_ticks, function(i) as.expression(bquote(10^ .(i))))
  
  y_ticks <- seq(y_low, y_high, by = 1)
  if (length(y_ticks) > nb_ticks_y){
    y_ticks = y_low + ceiling((y_high - y_low)/(nb_ticks_y + 1))*(0:nb_ticks_y)
  }
  y_labels <- sapply(y_ticks, function(i) as.expression(bquote(10^ .(i))))
  
  # Legend position
  if (is.null(legend_position)){
    if (which.min(abs(c(y_low, y_high) - log2(wv_rob$variance[1]))) == 1){
      legend_position = "topleft"
    }else{
      legend_position = "bottomleft"
    }
  }   
  
  # Main plot                     
  plot(NA, xlim = x_range, ylim = y_range, xlab = xlab, ylab = ylab, 
       log = "xy", xaxt = 'n', yaxt = 'n', bty = "n", ann = FALSE)
  win_dim = par("usr")
  
  par(new = TRUE)
  plot(NA, xlim = x_range, ylim = 10^c(win_dim[3], win_dim[4] + 0.09*(win_dim[4] - win_dim[3])),
       xlab = xlab, ylab = ylab, log = "xy", xaxt = 'n', yaxt = 'n', bty = "n")
  win_dim = par("usr")
  
  # Add grid
  abline(v = 2^x_ticks, lty = 1, col = "grey95")
  abline(h = 2^y_ticks, lty = 1, col = "grey95")
  
  # Add title
  x_vec = 10^c(win_dim[1], win_dim[2], win_dim[2], win_dim[1])
  y_vec = 10^c(win_dim[4], win_dim[4],
               win_dim[4] - 0.09*(win_dim[4] - win_dim[3]), 
               win_dim[4] - 0.09*(win_dim[4] - win_dim[3]))
  polygon(x_vec, y_vec, col = "grey95", border = NA)
  text(x = 10^mean(c(win_dim[1], win_dim[2])), y = 10^(win_dim[4] - 0.09/2*(win_dim[4] - win_dim[3])), main)
  
  # Add axes and box
  lines(x_vec[1:2], rep(10^(win_dim[4] - 0.09*(win_dim[4] - win_dim[3])),2), col = 1)
  y_ticks = y_ticks[(2^y_ticks) < 10^(win_dim[4] - 0.09*(win_dim[4] - win_dim[3]))]
  y_labels = y_labels[1:length(y_ticks)]
  box()
  axis(1, at = 2^x_ticks, labels = x_labels, padj = 0.3)
  axis(2, at = 2^y_ticks, labels = y_labels, padj = -0.2)  
  
  # CI for the WV
  polygon(c(wv_cl$scales, rev(wv_cl$scales)), c(wv_cl$ci_low, rev(wv_cl$ci_high)),
          border = NA, col = col_ci[1])
  
  polygon(c(wv_rob$scales, rev(wv_rob$scales)), c(wv_rob$ci_low, rev(wv_rob$ci_high)),
          border = NA, col = col_ci[2])
  
  if (!is.na(legend_position)){
    if (legend_position == "topleft"){
      legend_position = 10^c(1.1*win_dim[1], 0.98*(win_dim[4] - 0.09*(win_dim[4] - win_dim[3])))
      legend(x = legend_position[1], y = legend_position[2],
             legend = c("Classical WV", "Classical CI", "Robust WV", "Robust CI"),
             pch = c(16, 15, 16, 15), lty = c(1, NA, 1, NA), col = c(col_wv[1], col_ci[1], col_wv[2], col_ci[2]), 
             cex = 1, pt.cex = c(1.25, 3, 1.25, 3), bty = "n")
    }else{
      if (legend_position == "topright"){
        legend_position = 10^c(0.7*win_dim[2], 0.98*(win_dim[4] - 0.09*(win_dim[4] - win_dim[3])))
        legend(x = legend_position[1], y = legend_position[2],
               legend = c("Classical WV", "Classical CI", "Robust WV", "Robust CI"),
               pch = c(16, 15, 16, 15), lty = c(1, NA, 1, NA), col = c(col_wv[1], col_ci[1], col_wv[2], col_ci[2]), 
               cex = 1, pt.cex = c(1.25, 3, 1.25, 3), bty = "n")
      }else{
        legend(legend_position,
               legend = c("Classical WV", "Classical CI", "Robust WV", "Robust CI"),
               pch = c(16, 15, 16, 15), lty = c(1, NA, 1, NA), col = c(col_wv[1], col_ci[1], col_wv[2], col_ci[2]), 
               cex = 1, pt.cex = c(1.25, 3, 1.25, 3), bty = "n")
      }
    }
  }
  
  lines(wv_cl$scales, wv_cl$variance, type = "l", col = col_wv[1], pch = 16)
  lines(wv_cl$scales, wv_cl$variance, type = "p", col = col_wv[1], pch = 16, cex = 1.25)
  
  lines(wv_cl$scales, wv_rob$variance, type = "l", col = col_wv[2], pch = 16)
  lines(wv_cl$scales, wv_rob$variance, type = "p", col = col_wv[2], pch = 16, cex = 1.25)
  
}


#' @title Comparison between multiple Wavelet Variances
#' 
#' @description 
#' Displays plots of multiple wavelet variances of different time series accounting for CI values.
#' @param ... One or more time series objects.
#' @param nb_ticks_x An \code{integer} that specifies the maximum number of ticks for the x-axis.
#' @param nb_ticks_y An \code{integer} that specifies the maximum number of ticks for the y-axis.
#' @author Stephane Guerrier and Justin Lee
#' @export
#' @examples
#' set.seed(999)
#' n = 10^4
#' Xt = arima.sim(n = n, list(ar = 0.10))
#' Yt = arima.sim(n = n, list(ar = 0.35))
#' Zt = arima.sim(n = n, list(ar = 0.70))
#' Wt = arima.sim(n = n, list(ar = 0.95))
#' 
#' wv_Xt = wvar(Xt)
#' wv_Yt = wvar(Yt)
#' wv_Zt = wvar(Zt)
#' wv_Wt = wvar(Wt)
#' 
#' compare_wvar(wv_Xt, wv_Yt, wv_Zt, wv_Wt)
compare_wvar_split = function(..., nb_ticks_x = NULL, nb_ticks_y = NULL){
  
  obj_list = list(...)
  obj_name = as.character(substitute(...()))
  obj_len  = length(obj_list)
  
  # Check if passed objects are of the class wvar
  is_wvar = sapply(obj_list, FUN = is, class2 = 'wvar')
  
  if(!all(is_wvar == T)){
    stop("Supplied objects must be 'wvar' objects.")
  }
  
  # Check length
  if (obj_len == 0){
    stop('No object given!')
    
  }else if (obj_len == 1){
    # -> plot.wvar
    plot.wvar(..., nb_ticks_X = nb_ticks_x, nb_ticks_y = nb_ticks_y)
  }else{
    # Find x and y limits
    x_range = y_range = rep(NULL, 2)
    for (i in 1:obj_len){
      x_range = range(c(x_range, obj_list[[i]]$scales))
      y_range = range(c(y_range, obj_list[[i]]$ci_low, obj_list[[i]]$ci_high))
    }
    x_low = floor(log2(x_range[1]))
    x_high = ceiling(log2(x_range[2]))
    y_low = floor(log2(y_range[1]))
    y_high = ceiling(log2(y_range[2]))
    
    # Construct ticks
    # Axes
    if (is.null(nb_ticks_x)){
      nb_ticks_x = 6
    }
    
    if (is.null(nb_ticks_y)){
      nb_ticks_y = 5
    }
    
    x_ticks = seq(x_low, x_high, by = 1)
    if (length(x_ticks) > nb_ticks_x){
      x_ticks = x_low + ceiling((x_high - x_low)/(nb_ticks_x + 1))*(0:nb_ticks_x)
    }
    x_labels = sapply(x_ticks, function(i) as.expression(bquote(10^ .(i))))
    
    y_ticks = seq(y_low, y_high, by = 1)
    if (length(y_ticks) > nb_ticks_y){
      y_ticks = y_low + ceiling((y_high - y_low)/(nb_ticks_y + 1))*(0:nb_ticks_y)
    }
    y_labels = sapply(y_ticks, function(i) as.expression(bquote(10^ .(i))))
    
    # Define colors
    hues = seq(15, 375, length = obj_len + 1)
    col_wv = hcl(h = hues, l = 65, c = 100, alpha = 1)[seq_len(obj_len)]
    col_ci = hcl(h = hues, l = 65, c = 100, alpha = 0.15)[seq_len(obj_len)]
    
    par(mfrow = c(obj_len, obj_len), mar = c(0,0,0,0), oma = c(4,4,1,1))
    
    for (i in 1:obj_len){
      for (j in 1:obj_len){
        # Main plot                     
        plot(NA, xlim = x_range, ylim = y_range, log = "xy", xaxt = 'n', 
             yaxt = 'n', bty = "n", ann = FALSE)
        win_dim = par("usr")
        
        # Add grid
        abline(v = 2^x_ticks, lty = 1, col = "grey95")
        abline(h = 2^y_ticks, lty = 1, col = "grey95")
        
        # Add axes and box
        box(col = "grey")
        
        # Corner left piece
        if (j == 1){
          axis(2, at = 2^y_ticks, labels = y_labels, padj = -0.1, cex.axis = 1/log(obj_len)+0.1)  
        }
        
        # Corner bottom
        if (i == obj_len){
          axis(1, at = 2^x_ticks, labels = x_labels, padj = 0.1, cex.axis = 1/log(obj_len)+0.1)
        }
        # Diag graph
        if (i == j){
          scales   = obj_list[[i]]$scales
          ci_low   = obj_list[[i]]$ci_low
          ci_high  = obj_list[[i]]$ci_high
          variance = obj_list[[i]]$variance
          
          polygon(c(scales, rev(scales)), c(ci_low, rev(ci_high)),
                  border = NA, col = col_ci[i])
          lines(scales, variance, type = "l", col = col_wv[i], pch = 16)
        }
        
        if (i != j){
          scales   = obj_list[[i]]$scales
          ci_low   = obj_list[[i]]$ci_low
          ci_high  = obj_list[[i]]$ci_high
          variance = obj_list[[i]]$variance
          
          if (i < j){
            polygon(c(scales, rev(scales)), c(ci_low, rev(ci_high)),
                    border = NA, col = col_ci[i])
          }
          
          lines(scales, variance, type = "l", col = col_wv[i], pch = 16)
          
          scales   = obj_list[[j]]$scales
          ci_low   = obj_list[[j]]$ci_low
          ci_high  = obj_list[[j]]$ci_high
          variance = obj_list[[j]]$variance
          
          if (i < j){ # don't show confidence intervals 
            polygon(c(scales, rev(scales)), c(ci_low, rev(ci_high)),
                    border = NA, col = col_ci[j])
          }
          lines(scales, variance, type = "l", col = col_wv[j], pch = 16)
        }
      }
    }
    
    mtext(xlab, side = 2, line = 3, cex = 0.8, outer = T)
    mtext(ylab, side = 1, line = 3, cex = 0.8, outer = T)
    
  }
}

#'
#'@export
#'
compare_wvar_no_split = function(..., nb_ticks_x = NULL, nb_ticks_y = NULL){
  
  obj_list = list(...)
  obj_name = as.character(substitute(...()))
  obj_len  = length(obj_list)
  
  # Check if passed objects are of the class wvar
  is_wvar = sapply(obj_list, FUN = is, class2 = 'wvar')
  
  if(!all(is_wvar == T)){
    stop("Supplied objects must be 'wvar' objects.")
  }
  
  # Check length
  if (obj_len == 0){
    stop('No object given!')
    
  }else if (obj_len == 1){
    # -> plot.wvar
    plot.wvar(..., nb_ticks_X = nb_ticks_x, nb_ticks_y = nb_ticks_y)
  }else{
    # Find x and y limits
    x_range = y_range = rep(NULL, 2)
    for (i in 1:obj_len){
      x_range = range(c(x_range, obj_list[[i]]$scales))
      y_range = range(c(y_range, obj_list[[i]]$ci_low, obj_list[[i]]$ci_high))
    }
    x_low = floor(log2(x_range[1]))
    x_high = ceiling(log2(x_range[2]))
    y_low = floor(log2(y_range[1]))
    y_high = ceiling(log2(y_range[2]))
    
    # Construct ticks
    # Axes
    if (is.null(nb_ticks_x)){
      nb_ticks_x = 6
    }
    
    if (is.null(nb_ticks_y)){
      nb_ticks_y = 5
    }
    
    x_ticks = seq(x_low, x_high, by = 1)
    if (length(x_ticks) > nb_ticks_x){
      x_ticks = x_low + ceiling((x_high - x_low)/(nb_ticks_x + 1))*(0:nb_ticks_x)
    }
    x_labels = sapply(x_ticks, function(i) as.expression(bquote(10^ .(i))))
    
    y_ticks = seq(y_low, y_high, by = 1)
    if (length(y_ticks) > nb_ticks_y){
      y_ticks = y_low + ceiling((y_high - y_low)/(nb_ticks_y + 1))*(0:nb_ticks_y)
    }
    y_labels = sapply(y_ticks, function(i) as.expression(bquote(10^ .(i))))
    
    # Define colors
    hues = seq(15, 375, length = obj_len + 1)
    col_wv = hcl(h = hues, l = 65, c = 100, alpha = 1)[seq_len(obj_len)]
    col_ci = hcl(h = hues, l = 65, c = 100, alpha = 0.15)[seq_len(obj_len)]
    
    # Main plot                     
    plot(NA, xlim = x_range, ylim = y_range, log = "xy", xaxt = 'n', 
             yaxt = 'n', bty = "n", ann = FALSE)
    win_dim = par("usr")
    
    # Main plot                   
    par(new = TRUE)
    plot(NA, xlim = x_range, ylim = 10^c(win_dim[3], win_dim[4] + 0.09*(win_dim[4] - win_dim[3])),
        log = "xy", xaxt = 'n', yaxt = 'n', bty = "n")
    win_dim = par("usr")
    
    # Add grid
    abline(v = 2^x_ticks, lty = 1, col = "grey95")
    abline(h = 2^y_ticks, lty = 1, col = "grey95")
    
    # Add title
    x_vec = 10^c(win_dim[1], win_dim[2], win_dim[2], win_dim[1])
    y_vec = 10^c(win_dim[4], win_dim[4],
                 win_dim[4] - 0.09*(win_dim[4] - win_dim[3]), 
                 win_dim[4] - 0.09*(win_dim[4] - win_dim[3]))
    polygon(x_vec, y_vec, col = "grey95", border = NA)
    text(x = 10^mean(c(win_dim[1], win_dim[2])), y = 10^(win_dim[4] - 0.09/2*(win_dim[4] - win_dim[3])), "WV")
    
    # Add axes and box
    lines(x_vec[1:2], rep(10^(win_dim[4] - 0.09*(win_dim[4] - win_dim[3])),2), col = 1)
    y_ticks = y_ticks[(2^y_ticks) < 10^(win_dim[4] - 0.09*(win_dim[4] - win_dim[3]))]
    y_labels = y_labels[1:length(y_ticks)]
    box()
    axis(1, at = 2^x_ticks, labels = x_labels, padj = 0.3)
    axis(2, at = 2^y_ticks, labels = y_labels, padj = -0.2)  
        
   for (i in 1:obj_len){
     scales   = obj_list[[i]]$scales
     ci_low   = obj_list[[i]]$ci_low
     ci_high  = obj_list[[i]]$ci_high
     variance = obj_list[[i]]$variance
     
     polygon(c(scales, rev(scales)), c(ci_low, rev(ci_high)),
             border = NA, col = col_ci[i])
     lines(scales, variance, type = "l", col = col_wv[i], pch = 16)
    }
  }
}







#' @title Comparison Between Multiple Wavelet Variances
#' @description 
#' Displays plots of multiple wavelet variances of different time series accounting for CI values.
#' 
#' @param ... One or more time series objects.
#' @param split           A \code{boolean} that, if TRUE, arranges the plots into a matrix-like format.
#' @param units           A \code{string} that specifies the units of time plotted on the x axes.
#' @param xlab            A \code{string} that gives a title for the x axes.
#' @param ylab            A \code{string} that gives a title for the y axes.
#' @param main            A \code{string} that gives an overall title for the plot.
#' @param nb_ticks_x      An \code{integer} that specifies the maximum number of ticks for the x-axis.
#' @param nb_ticks_y      An \code{integer} that specifies the maximum number of ticks for the y-axis.
#' @param legend_position  A \code{string} that specifies the position of the legend (use \code{legend_position = NA} to remove legend).
#' @param ci_wv            A \code{double} that specifies the confidence interval to be used in the WV calculation.
#' @param point_pch        A \code{double} that specifies the symbol type to be plotted.
#' @param point_cex        A \code{double} that specifies the size of each symbol to be plotted.
#' 
#' @author Stephane Guerrier and Justin Lee
#' @export
#' @examples
#' set.seed(999)
#' n = 10^4
#' Xt = arima.sim(n = n, list(ar = 0.10))
#' Yt = arima.sim(n = n, list(ar = 0.35))
#' Zt = arima.sim(n = n, list(ar = 0.70))
#' Wt = arima.sim(n = n, list(ar = 0.95))
#' 
#' wv_Xt = wvar(Xt)
#' wv_Yt = wvar(Yt)
#' wv_Zt = wvar(Zt)
#' wv_Wt = wvar(Wt)
#' 
#' compare_wvar(wv_Xt, wv_Yt, wv_Zt, wv_Wt)
compare_wvar = function(... , split = "FALSE", units = NULL, xlab = "Scales", ylab = "Wavelet Variance", main = NULL, 
                        col_wv = NULL, col_ci = NULL, nb_ticks_x = NULL, nb_ticks_y = NULL,
                        legend_position = NULL, ci_wv = NULL, point_cex = NULL, 
                        point_pch = NULL, names = NULL){
  
  obj_list = list(...)
  obj_name = as.character(substitute(...()))
  obj_len  = length(obj_list)
  obj_len
  
  #Passed into compare_wvar_split or compare_wvar_no_split
  graph_details = list(obj_name, names = names, xlab = xlab, ylab = ylab, col_wv = col_wv, 
                       col_ci = col_ci, main = main, legend_position = legend_position,
                       ci_wv = ci_wv, point_cex = point_cex, point_pch = point_pch)
  
  # Check if passed objects are of the class wvar
  is_wvar = sapply(obj_list, FUN = is, class2 = 'wvar')
  
  if(!all(is_wvar == T)){
    stop("Supplied objects must be 'wvar' objects.")
  }
  
  # Check length
  if (obj_len == 0){
    stop('No object given!')
  }else if (obj_len == 1){
    # -> plot.wvar
    plot.wvar(..., nb_ticks_X = nb_ticks_x, nb_ticks_y = nb_ticks_y)
  }else{
  
    # Labels
    if (is.null(xlab)){
      if (is.null(units)){
        xlab = expression(paste("Scale ", tau, sep =""))
      }else{
        xlab = bquote(paste("Scale ", tau, " [", .(units), "]", sep = " "))
      }
    }
    
    if (is.null(ylab)){
      if(is.null(units)){
        ylab = expression(paste("Wavelet Variance ", nu^2, sep = ""))
      }else{
        ylab = bquote(paste("Wavelet Variance ", nu^2, " [", .(units)^2, "]", sep = " "))
      }
    }
    
    if (is.null(ci_wv)){
      ci_wv = rep(TRUE, obj_len)
    }else{
      if (length(ci_wv) != obj_len){
        ci_wv = rep(TRUE, obj_len)
      }
    }
    # Main Title
    if (split == "FALSE"){
      if (is.null(main)){
        main = "Haar Wavelet Variance Representation"
      }
    }
    
    hues = seq(15, 375, length = obj_len + 1)
    # Line and CI colors
    if (is.null(col_wv)){
      col_wv = hcl(h = hues, l = 65, c = 100, alpha = 1)[seq_len(obj_len)]
    }else{
      if (length(col_wv) != obj_len){
        col_wv = hcl(h = hues, l = 65, c = 100, alpha = 1)[seq_len(obj_len)]
      }
    }
    
    if (is.null(col_ci)){
      col_ci = hcl(h = hues, l = 65, c = 100, alpha = 0.15)[seq_len(obj_len)]
    }else{
      if (length(col_ci) != obj_len){
        col_ci = hcl(h = hues, l = 65, c = 100, alpha = 0.15)[seq_len(obj_len)]
      }
    }
    
    # Range
    # Find x and y limits
    x_range = y_range = rep(NULL, 2)
    for (i in 1:obj_len){
      x_range = range(c(x_range, obj_list[[i]]$scales))
      y_range = range(c(y_range, obj_list[[i]]$ci_low, obj_list[[i]]$ci_high))
    }
    
    x_low = floor(log2(x_range[1]))
    x_high = ceiling(log2(x_range[2]))
    y_low = floor(log2(y_range[1]))
    y_high = ceiling(log2(y_range[2]))
    
    # Axes
    if (is.null(nb_ticks_x)){
      nb_ticks_x = 6
    }
    
    if (is.null(nb_ticks_y)){
      nb_ticks_y = 5
    }
    
    x_ticks = seq(x_low, x_high, by = 1)
    if (length(x_ticks) > nb_ticks_x){
      x_ticks = x_low + ceiling((x_high - x_low)/(nb_ticks_x + 1))*(0:nb_ticks_x)
    }
    x_labels = sapply(x_ticks, function(i) as.expression(bquote(10^ .(i))))
    
    y_ticks <- seq(y_low, y_high, by = 1)
    if (length(y_ticks) > nb_ticks_y){
      y_ticks = y_low + ceiling((y_high - y_low)/(nb_ticks_y + 1))*(0:nb_ticks_y)
    }
    y_labels <- sapply(y_ticks, function(i) as.expression(bquote(10^ .(i))))
    
    # Legend position
  #  if (is.null(legend_position)){
  #    if (which.min(abs(c(y_low, y_high) - log2(x$variance[1]))) == 1){
  #      legend_position = "topleft"
  #    }else{
  #      legend_position = "bottomleft"
  #    }
  #  }
    
    if (is.null(point_pch)){
      inter = rep(15:17, obj_len)
      point_pch = inter[1:obj_len]
    }else{
      if (length(point_pch) != obj_len){
        inter = rep(15:17, obj_len)
        point_pch = inter[1:obj_len]
      }
    }
    
    if (is.null(point_cex)){
      point_cex = rep(1.25, obj_len)
    }else{
      if (length(point_pch) != obj_len){
        point_cex = rep(1.25, obj_len)
      }
    }
    
    if (is.null(names)){
        names = obj_name
    }else{
      if (length(names) != obj_len){
        names = obj_name
      }
    }
    
    if (split == FALSE){
      # CALL compare_wvar_no_split
      compare_wvar_no_split(graph_details)
    }else{
      # CALL compare_wvar_split
      compare_wvar_split(graph_details)
    }
  }
}

n = 10^5
Xt = arima.sim(n = n, list(ar = 0.10))
Yt = arima.sim(n = n, list(ar = 0.35))
Zt = arima.sim(n = n, list(ar = 0.70))
Wt = arima.sim(n = n, list(ar = 0.95))

wv_Xt = wvar(Xt)
wv_Yt = wvar(Yt)
wv_Zt = wvar(Zt)
wv_Wt = wvar(Wt)

compare_wvar(wv_Xt, wv_Yt, wv_Zt, wv_Wt)
