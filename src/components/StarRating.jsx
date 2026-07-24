import { FiStar } from "react-icons/fi";
import "./StarRating.css";

export default function StarRating({ rating, showNumber = false }) {
  return (
    <div className="star-rating">
      {[1, 2, 3, 4, 5].map((n) => (
        <FiStar
          key={n}
          className={n <= rating ? "star filled" : "star"}
        />
      ))}
      {showNumber && <span className="star-number">{rating}/5</span>}
    </div>
  );
}