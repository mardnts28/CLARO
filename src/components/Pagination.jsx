import { useMemo } from "react";
import {
  FiChevronLeft,
  FiChevronRight,
  FiChevronsLeft,
  FiChevronsRight,
} from "react-icons/fi";
import "./Pagination.css";

export default function Pagination({
  currentPage = 1,
  totalItems = 0,
  pageSize = 20,
  onPageChange,
  onPageSizeChange,
  pageSizeOptions = [20, 30, 50],
}) {
  const totalPages = Math.max(1, Math.ceil(totalItems / pageSize));

  const startItem = totalItems === 0 ? 0 : (currentPage - 1) * pageSize + 1;
  const endItem = Math.min(currentPage * pageSize, totalItems);

  // Generate pagination buttons with smart ellipsis
  const pageNumbers = useMemo(() => {
    const pages = [];
    const maxVisiblePages = 5;

    if (totalPages <= maxVisiblePages) {
      for (let i = 1; i <= totalPages; i++) {
        pages.push(i);
      }
    } else {
      // Always include page 1
      pages.push(1);

      let start = Math.max(2, currentPage - 1);
      let end = Math.min(totalPages - 1, currentPage + 1);

      if (currentPage <= 2) {
        end = 3;
      } else if (currentPage >= totalPages - 1) {
        start = totalPages - 2;
      }

      if (start > 2) {
        pages.push("ellipsis-1");
      }

      for (let i = start; i <= end; i++) {
        pages.push(i);
      }

      if (end < totalPages - 1) {
        pages.push("ellipsis-2");
      }

      // Always include last page
      pages.push(totalPages);
    }

    return pages;
  }, [currentPage, totalPages]);

  if (totalItems === 0) return null;

  return (
    <div className="pagination-container">
      <div className="pagination-info">
        <span className="pagination-count">
          Showing <strong>{startItem}</strong> – <strong>{endItem}</strong> of{" "}
          <strong>{totalItems}</strong> records
        </span>

        {onPageSizeChange && (
          <div className="pagination-size-selector">
            <label htmlFor="pagination-size-select">Per page:</label>
            <select
              id="pagination-size-select"
              className="pagination-size-select"
              value={pageSize}
              onChange={(e) => onPageSizeChange(Number(e.target.value))}
            >
              {pageSizeOptions.map((opt) => (
                <option key={opt} value={opt}>
                  {opt}
                </option>
              ))}
            </select>
          </div>
        )}
      </div>

      <div className="pagination-controls">
        <button
          type="button"
          className="pagination-btn"
          onClick={() => onPageChange(1)}
          disabled={currentPage === 1}
          title="First Page"
          aria-label="First Page"
        >
          <FiChevronsLeft />
        </button>

        <button
          type="button"
          className="pagination-btn"
          onClick={() => onPageChange(currentPage - 1)}
          disabled={currentPage === 1}
          title="Previous Page"
          aria-label="Previous Page"
        >
          <FiChevronLeft />
        </button>

        {pageNumbers.map((page, index) => {
          if (typeof page === "string") {
            return (
              <span key={`ellipsis-${index}`} className="pagination-ellipsis">
                …
              </span>
            );
          }

          return (
            <button
              key={page}
              type="button"
              className={`pagination-btn ${page === currentPage ? "active" : ""}`}
              onClick={() => onPageChange(page)}
              aria-current={page === currentPage ? "page" : undefined}
            >
              {page}
            </button>
          );
        })}

        <button
          type="button"
          className="pagination-btn"
          onClick={() => onPageChange(currentPage + 1)}
          disabled={currentPage === totalPages}
          title="Next Page"
          aria-label="Next Page"
        >
          <FiChevronRight />
        </button>

        <button
          type="button"
          className="pagination-btn"
          onClick={() => onPageChange(totalPages)}
          disabled={currentPage === totalPages}
          title="Last Page"
          aria-label="Last Page"
        >
          <FiChevronsRight />
        </button>
      </div>
    </div>
  );
}
